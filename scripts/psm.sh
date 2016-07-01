yum -y install java-1.8.0-openjdk-devel

# dependent services
yum -y install freeradius freeradius-mysql freeradius-utils && systemctl enable radiusd && systemctl start radiusd
yum -y install mariadb mariadb-libs mariadb-server && systemctl enable mariadb && systemctl start mariadb
yum -y install net-snmp net-snmp-agent-libs net-snmp-libs net-snmp-utils && systemctl enable snmpd && systemctl start snmpd
yum -y install proftpd && systemctl enable proftpd && systemctl start proftpd
yum -y install cronie ntp ntpdate openssh-clients && systemctl enable ntpd && systemctl start ntpd && systemctl enable crond && systemctl start crond

array=( radiusd mariadb snmpd proftpd ntpd crond )
for i in "${array[@]}"
do
mkdir /etc/systemd/system/$i.service.d
cat > /etc/systemd/system/$i.service.d/restart.conf <<EOF
[Service]
Restart=always
RestartSec=3
EOF
done

systemctl daemon-reload

for i in "${array[@]}"
do
	systemctl restart $i
done


# useful third party scripts
wget http://mysqltuner.pl/ -O /usr/local/sbin/mysqltuner.pl && chmod +x /usr/local/sbin/mysqltuner.pl
