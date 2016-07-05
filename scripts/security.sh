# needs to be done outside of kickstart for packer to work
yum -y install firewalld && systemctl enable firewalld && systemctl start firewalld.service

# selinux is running by default in centos 7 and is using https://github.com/TresysTechnology/refpolicy/wiki
