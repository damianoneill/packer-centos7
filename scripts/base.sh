yum -y update
yum -y install ca-certificates net-tools chrony screen tree vim wget psmisc htop policycoreutils

cat /dev/zero | ssh-keygen -q -t rsa -N ""
