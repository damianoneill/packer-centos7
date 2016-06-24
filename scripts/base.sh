yum -y update
yum -y install dbus npm js-devel httpd htop ftp dos2unix wget mariadb-server net-snmp net-snmp-libs net-snmp-utils freeradius freeradius-utils freeradius-mysql mlocate screen ntp traceroute perf genisoimage x86info dmidecode pciutils hdparm expect telnet tcpdump git python-paramiko python-pip dejavu-lgc-sans-fonts iptables-services irqbalance isomd5sum libxml2-devel libxslt libxslt-devel libXtst lsof lzo m2crypto mailx man-pages net-tools numactl parted perl-devel perl-IO-Socket-SSL perl-TermReadKey php-cli php-common pyparsing python-amqplib python-devel python-pyasn1 python-simplejson pytz sgml-common sysstat tcsh tmux vconfig xorg-x11-apps xorg-x11-fonts-misc xorg-x11-server-Xorg xorg-x11-xauth xorg-x11-xbitmaps xterm zip curl openssh-server

yum -y install libxml2 libxml2-python deltarpm python-deltarpm createrepo

# Install root certificates
yum -y install ca-certificates
