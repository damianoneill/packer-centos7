yum -y erase gtk2 libX11 hicolor-icon-theme avahi freetype bitstream-vera-fonts avahi-autoipd avahi-libs avahi
yum -y clean all
systemctl stop postfix && yum -y remove postfix
