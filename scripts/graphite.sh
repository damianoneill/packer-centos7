PM_DIR="/backups/pms"
GRAPHITE_SETTINGS="/opt/graphite/webapp/graphite/settings.py"

yum -y install pycairo mod_wsgi python-memcached pyOpenSSL python-pip gcc python-devel

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

pushd /opt/graphite/webapp/graphite/ &> /dev/null 2>&1
python manage.py syncdb --noinput &> /dev/null 2>&1
popd &> /dev/null 2>&1

if [ ! -d ${PM_DIR} ]; then
  mkdir -p ${PM_DIR}
  echo ">>> created ${PM_DIR}"
fi
