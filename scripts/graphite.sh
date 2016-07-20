HISTORICAL_PM_DIR="/backups/pms"
APACHE_DIR="/etc/httpd/conf.d"
GRAPHITE_CONFIG="${APACHE_DIR}/graphite.conf"
GRAPHITE_DIR="/opt/graphite"
GRAPHITE_SETTINGS="${GRAPHITE_DIR}/webapp/graphite/settings.py"
GRAPHITE_CONF_DIR="${GRAPHITE_DIR}/conf"
CARBON_CONFIG="${GRAPHITE_CONF_DIR}/carbon.conf"
STORAGE_CONFIG="${GRAPHITE_CONF_DIR}/storage-schemas.conf"
GRAPHITE_WSGI_CONFIG="${GRAPHITE_CONF_DIR}/graphite.wsgi"
GRAPHITE_WEBAPP_DIR="${GRAPHITE_DIR}/webapp"
GRAPHITE_LOCAL_SETTINGS="${GRAPHITE_WEBAPP_DIR}/graphite/local_settings.py"

yum -y install pycairo mod_wsgi python-memcached pyOpenSSL python-pip gcc python-devel policycoreutils-python pytz

PIP_INSTALLS=( 'django<1.9' 'django-tagging' 'Twisted<12.0' 'zope.interface' 'db-sqlite3' 'carbon<0.9.13' 'whisper' 'graphite-web' )

for i in "${PIP_INSTALLS[@]}"
do
  pip install ${i} &> /dev/null 2>&1
  if [ $? -eq 0 ]; then
    RESULT="success"
  else
    RESULT="FAILED"
  fi
  echo ">>> pip installed ${i} (${RESULT})"
done

echo ">>> Initializing PM graphing database"
if ! grep -q "'NAME': '/opt/graphite/storage/graphite.db'," ${GRAPHITE_SETTINGS}; then
  printf "%s\n" "DATABASES = {" >> ${GRAPHITE_SETTINGS}
  printf "%s\n" "  'default': {" >> ${GRAPHITE_SETTINGS}
  printf "%s\n" "    'NAME': '/opt/graphite/storage/graphite.db'," >> ${GRAPHITE_SETTINGS}
  printf "%s\n" "    'ENGINE': 'django.db.backends.sqlite3'," >> ${GRAPHITE_SETTINGS}
  printf "%s\n" "    'USER': ''," >> ${GRAPHITE_SETTINGS}
  printf "%s\n" "    'PASSWORD': ''," >> ${GRAPHITE_SETTINGS}
  printf "%s\n" "    'HOST': ''," >> ${GRAPHITE_SETTINGS}
  printf "%s\n" "    'PORT': ''" >> ${GRAPHITE_SETTINGS}
  printf "%s\n" "  }" >> ${GRAPHITE_SETTINGS}
  printf "%s\n" "}" >> ${GRAPHITE_SETTINGS}
  echo ">>> ${GRAPHITE_SETTINGS} updated"
fi

if [ ! -d ${HISTORICAL_PM_DIR} ]; then
  mkdir -p ${HISTORICAL_PM_DIR}
  echo ">>> created ${HISTORICAL_PM_DIR}"
fi

echo ">>> Provisioning Graphite configuration"
cat > ${GRAPHITE_CONFIG} <<-EOF
	 Listen 8080
	<VirtualHost *:8080>
	  DocumentRoot "/opt/graphite/webapp"
	  ErrorLog logs/graphite_error_log
	  TransferLog logs/graphite_access_log
	  LogLevel warn
	  WSGIDaemonProcess graphite processes=5 threads=5 display-name=" {GROUP}" inactivity-timeout=120
	  WSGIProcessGroup graphite
	  WSGIScriptAlias / /opt/graphite/conf/graphite.wsgi
	  Alias /content/ /opt/graphite/webapp/content/
		Alias /media/ "/usr/lib/python2.7/site-packages/django/contrib/admin/
		<Directory /opt/graphite/conf/>
			Order deny,allow
			Allow from all
			Require all granted
		</Directory>
		<Directory /opt/graphite/webapp/content/>
			Order deny,allow
			Allow from all
			Require all granted
		</Directory>
	</VirtualHost>
EOF

echo ">>> Provisioning Apache configuration"
cat > ${APACHE_DIR}/wsgi.conf <<-EOF
LoadModule wsgi_module modules/mod_wsgi.so
WSGISocketPrefix /var/run/wsgi
EOF

echo ">>> Provisiong PM database"
if [ ! -f ${CARBON_CONFIG} ]; then
		cp ${CARBON_CONFIG}.example ${CARBON_CONFIG}
fi

if grep -q "#LOCAL_DATA_DIR" ${CARBON_CONFIG}; then
	if grep -q "LOCAL_DATA_DIR" ${CARBON_CONFIG}; then
		sed -i "2i\LOCAL_DATA_DIR = ${HISTORICAL_PM_DIR}" ${CARBON_CONFIG}
	else
		sed -i "s:LOCAL_DATA_DIR\s* = .*:LOCAL_DATA_DIR = ${HISTORICAL_PM_DIR}/:" ${CARBON_CONFIG}
	fi
else
	sed -i "s:#LOCAL_DATA_DIR\s* = .*:LOCAL_DATA_DIR = ${HISTORICAL_PM_DIR}/:" ${CARBON_CONFIG}
fi

sed -i -e "s/MAX_CREATES_PER_MINUTE\s* = .*/MAX_CREATES_PER_MINUTE = 600000/" \
	-e "s/MAX_UPDATES_PER_SECOND\s* = .*/MAX_UPDATES_PER_SECOND = 10000/" ${CARBON_CONFIG}

cat > ${STORAGE_CONFIG} <<-EOF
[15min_for_30days]
pattern = .*15-Min.*
retentions = 900s:30d
[1Day_for_30days]
pattern = .*1-Day.*
retentions = 1d:30d
EOF

echo ">>> Provisioning WSGI setup"
if [ ! -f ${GRAPHITE_WSGI_CONFIG} ] && [ -f ${GRAPHITE_WSGI_CONFIG}.example ]; then
		cp ${GRAPHITE_WSGI_CONFIG}.example ${GRAPHITE_WSGI_CONFIG}
		sed -i '1i#PSM-CREATED' ${GRAPHITE_WSGI_CONFIG}
fi

if [ -f ${GRAPHITE_LOCAL_SETTINGS}.example ]; then
	cp -f ${GRAPHITE_LOCAL_SETTINGS}.example ${GRAPHITE_LOCAL_SETTINGS}
	printf "\nDATA_DIRS = ['%s']\nTIME_ZONE = 'Etc/GMT'\n" ${HISTORICAL_PM_DIR} >> ${GRAPHITE_LOCAL_SETTINGS}
fi

echo ">>> Configuring SELinux rules"
#semanage fcontext -a -t httpd_sys_content_t /opt/graphite/webapp/graphite/local_settings.pyc > /dev/null 2>&1
#semanage fcontext -a -t httpd_sys_content_t /opt/graphite/storage/log/webapp > /dev/null 2>&1

#chcon -Rv --type=httpd_sys_content_t /opt/graphite/webapp/graphite/local_settings.pyc /dev/null 2>&1
#chcon -Rv --type=httpd_sys_content_t /opt/graphite/storage/log/webapp /dev/null 2>&1

#setsebool -P httpd_unified 1

echo ">>> Initial Database creation"
python ${GRAPHITE_WEBAPP_DIR}/graphite/manage.py syncdb --noinput > /dev/null 2>&1
chown -R apache:apache ${GRAPHITE_DIR}/storage


echo ">>> Provisioning Carbon Systemd"
cat > /lib/systemd/system/carbon.service <<EOF
[Unit]
Description=Carbon Process
After=syslog.target network.target

[Service]
Type=forking
Restart=always
RestartSec=3
GuessMainPID = false
PIDFile = /opt/graphite/storage/carbon-cache-a.pid
ExecStart=/opt/graphite/bin/carbon-cache.py start
LimitNOFILE=128000

[Install]
WantedBy=multi-user.target
EOF
chmod 644 /lib/systemd/system/carbon.service

echo ">>> Reloading Systemd"
systemctl daemon-reload

echo ">>> Starting carbon and httpd"
systemctl start carbon && systemctl enable carbon
systemctl restart httpd && systemctl enable httpd

echo ">>> Add rules to firewall for graphite"
firewall-cmd --add-port=8080/tcp --permanent
firewall-cmd --reload
