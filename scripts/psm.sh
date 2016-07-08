# cant do anything without java
yum -y install java-1.8.0-openjdk-devel

# required utilities
yum -y install git lshw hdparm

# install software in case a MTA is required and disable it by default
yum -y install sendmail sendmail-cf m4 && systemctl disable sendmail && systemctl stop sendmail

# dependent services
yum -y install freeradius freeradius-mysql freeradius-utils && systemctl enable radiusd && systemctl start radiusd
yum -y install mariadb mariadb-libs mariadb-server mysqltuner holland-mysqldump && systemctl enable mariadb && systemctl start mariadb
yum -y install net-snmp net-snmp-agent-libs net-snmp-libs net-snmp-utils && systemctl enable snmpd && systemctl start snmpd
yum -y install proftpd && systemctl enable proftpd && systemctl start proftpd
yum -y install cronie && systemctl enable crond && systemctl start crond

# make the services restart on fail
services=( radiusd mariadb snmpd proftpd crond )
for i in "${services[@]}"
do
mkdir /etc/systemd/system/$i.service.d
cat > /etc/systemd/system/$i.service.d/restart.conf <<EOF
[Service]
Restart=always
RestartSec=3
EOF
done

systemctl daemon-reload
for i in "${services[@]}"
do
	systemctl restart $i
done

cat > /usr/lib/firewalld/services/snmp.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<service>
  <short>SNMP</short>
  <description>SNMP protocol</description>
  <port protocol="udp" port="161"/>
</service>
EOF

firewall-cmd --reload

# open some of the services through the firewall
firewallservices=( radius ftp ntp snmp )
for i in "${firewallservices[@]}"
do
	firewall-cmd --add-service=$i --permanent
done
firewall-cmd --reload


# set selinux settings
# setsebool -P allow_ftpd_full_access=1


# secure mariadb, not touching the default password for root, at this point its still empty
mysql -u root <<-EOF
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DELETE FROM mysql.user WHERE User='';
DROP DATABASE test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';
FLUSH PRIVILEGES;
EOF

# configure holland to backup the mysql database, at 1:10am and to keep 7 backups in /var/spool/holland
wget https://raw.githubusercontent.com/holland-backup/holland/master/config/backupsets/default.conf -O /etc/holland/backupsets/default.conf
sed -i -e 's/backups-to-keep = 1/backups-to-keep = 7/g' /etc/holland/backupsets/default.conf
(crontab -l ; echo "10 1 * * * /usr/sbin/holland -q bk") | crontab
