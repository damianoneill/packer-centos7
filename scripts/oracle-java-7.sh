wget --no-cookies --no-check-certificate --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/7u80-b15/jdk-7u80-linux-x64.rpm"
rpm -ivh jdk-7u80-linux-x64.rpm
rm -f jdk-7u80-linux-x64.rpm

yum -y install words
genhostname=`shuf -n1  /usr/share/dict/words`
hostnamectl set-hostname $genhostname
ip=`hostname -I`
echo "$ip	$genhostname" >> /etc/hosts
