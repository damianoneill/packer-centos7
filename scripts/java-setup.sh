yum -y install java-1.8.0-openjdk-devel git wget unzip

wget https://services.gradle.org/distributions/gradle-3.4.1-bin.zip
mkdir /opt/gradle
unzip -d /opt/gradle gradle-3.4.1-bin.zip
rm -rf gradle-3.4.1-bin.zip
echo 'export PATH=$PATH:/opt/gradle/gradle-3.4.1/bin' >> ~/.bash_profile
