#!/bin/bash
#set -e
# sh test frey frey pod1.avxlab.cc pod1 avxlab.cc
# Arguments:  1=username 2=password 3=fqdn 4=pod_id 5=domain_name

LOG="/tmp/guac-install.log"

# Install all the needed packages
sudo apt-get update >> $LOG
sudo apt-get install xrdp lxde make gcc g++ libcairo2-dev libjpeg-turbo8-dev libpng-dev libtool-bin libossp-uuid-dev libavcodec-dev libavutil-dev libswscale-dev freerdp2-dev libpango1.0-dev libssh2-1-dev libvncserver-dev libtelnet-dev libssl-dev libvorbis-dev libwebp-dev tomcat9 tomcat9-admin tomcat9-common tomcat9-user nginx -y >> $LOG

# Start and enable Tomcat
sudo systemctl start tomcat9 >> $LOG
sudo systemctl enable tomcat9 >> $LOG

# Download and install Guacamole Server
wget https://downloads.apache.org/guacamole/1.1.0/source/guacamole-server-1.1.0.tar.gz -P /tmp/ >> $LOG
tar xzf /tmp/guacamole-server-1.1.0.tar.gz -C /tmp/ >> $LOG

(
    cd /tmp/guacamole-server-1.1.0 
    sudo ./configure --with-init-dir=/etc/init.d >> $LOG
    sudo make >> $LOG
    sudo make install >> $LOG
    sudo ldconfig >> $LOG
)

sudo systemctl start guacd >> $LOG
sudo systemctl enable guacd  >> $LOG


####
sudo mkdir /etc/guacamole >> $LOG

echo "<user-mapping>
<authorize 
    username=\"$1\"
    password=\"$2\">
  <connection name=\"SSH - Client\">
    <protocol>ssh</protocol>
    <param name=\"hostname\">localhost</param>
    <param name=\"port\">22</param>
  </connection>
  <connection name=\"SSH - Web\">
    <protocol>ssh</protocol>
    <param name=\"hostname\">web.${4}.${5}</param>
    <param name=\"port\">22</param>
  </connection>
  <connection name=\"SSH - App\">
    <protocol>ssh</protocol>
    <param name=\"hostname\">app.${4}.${5}</param>
    <param name=\"port\">22</param>
  </connection>
  <connection name=\"SSH - DB\">
    <protocol>ssh</protocol>
    <param name=\"hostname\">db.${4}.${5}</param>
    <param name=\"port\">22</param>
  </connection>      
  <connection name=\"RDP - Client\">
    <protocol>rdp</protocol>
    <param name=\"hostname\">localhost</param>
    <param name=\"port\">3389</param>
    <param name=\"username\">$1</param>
    <param name=\"password\">$2</param>
  </connection>
</authorize>
</user-mapping>" | sudo tee -a /etc/guacamole/user-mapping.xml


sudo wget https://downloads.apache.org/guacamole/1.1.0/binary/guacamole-1.1.0.war -O /etc/guacamole/guacamole.war  >> $LOG
sudo ln -s /etc/guacamole/guacamole.war /var/lib/tomcat9/webapps/  >> $LOG
sleep 10  >> $LOG
sudo mkdir /etc/guacamole/{extensions,lib}  >> $LOG
sudo bash -c 'echo "GUACAMOLE_HOME=/etc/guacamole" >> /etc/default/tomcat9'

echo "guacd-hostname: localhost
guacd-port:    4822
user-mapping:    /etc/guacamole/user-mapping.xml
auth-provider:    net.sourceforge.guacamole.net.basic.BasicFileAuthenticationProvider"  | sudo tee -a /etc/guacamole/guacamole.properties

sudo ln -s /etc/guacamole /usr/share/tomcat9/.guacamole

sudo systemctl restart tomcat9  >> $LOG
sudo systemctl restart guacd  >> $LOG

#####
# Create user for RDP session
sudo useradd -m -s /bin/bash $1  >> $LOG
echo "$1:$2" | sudo chpasswd

# Download ssl cert for nginx
sudo wget https://avx-build.s3.eu-central-1.amazonaws.com/san-cert.crt -O /etc/nginx/cert.crt  >> $LOG
sudo wget https://avx-build.s3.eu-central-1.amazonaws.com/san-cert.key -O /etc/nginx/cert.key  >> $LOG
sudo systemctl start nginx  >> $LOG
sudo systemctl enable nginx  >> $LOG

# Create Desktop shortcuts
sudo mkdir /home/$1/Desktop

echo "[Desktop Entry]
Type=Link
Name=Firefox Web Browser
Icon=firefox
URL=/usr/share/applications/firefox.desktop" | sudo tee -a /home/$1/Desktop/firefox.desktop

echo "[Desktop Entry]
Type=Link
Name=LXTerminal
Icon=lxterminal
URL=/usr/share/applications/lxterminal.desktop" | sudo tee -a /home/$1/Desktop/lxterminal.desktop

sudo chown $1:$1 /home/$1/Desktop  >> $LOG
sudo chown $1:$1 /home/$1/Desktop/*  >> $LOG

# Nginx config - SSL redirect
echo "server {
    listen 80;
	  server_name $3;
    return 301 https://\$host\$request_uri;
}
server {
	listen 443 ssl;
	server_name $3;

  ssl_certificate /etc/nginx/cert.crt;
	ssl_certificate_key /etc/nginx/cert.key;
	ssl_protocols TLSv1.2;
	ssl_prefer_server_ciphers on; 
	add_header X-Frame-Options DENY;
	add_header X-Content-Type-Options nosniff;

	access_log  /var/log/nginx/guac_access.log;
	error_log  /var/log/nginx/guac_error.log;

	location / {
		    proxy_pass http://localhost:8080/guacamole/;
		    proxy_buffering off;
		    proxy_http_version 1.1;
		    proxy_cookie_path /guacamole/ /;
	}
}" | sudo tee -a /etc/nginx/conf.d/default.conf

sudo systemctl restart nginx  >> $LOG

# Customize Guacamole login page
sudo ls -l /var/lib/tomcat9/webapps/guacamole/  >> $LOG
sudo wget https://avx-build.s3.eu-central-1.amazonaws.com/logo-144.png  >> $LOG
sudo wget https://avx-build.s3.eu-central-1.amazonaws.com/logo-64.png  >> $LOG
# while [ ! -d /var/lib/tomcat9/webapps/guacamole/images/ ]; do
#   sleep 1
# done
sudo cp logo-144.png /var/lib/tomcat9/webapps/guacamole/images/  >> $LOG
sudo cp logo-64.png /var/lib/tomcat9/webapps/guacamole/images/  >> $LOG
sudo cp logo-144.png /var/lib/tomcat9/webapps/guacamole/images/guac-tricolor.png  >> $LOG
sudo sed -i "s/Apache Guacamole/Aviatrix Build - $4/g" /var/lib/tomcat9/webapps/guacamole/translations/en.json  >> $LOG
sudo systemctl restart tomcat9  >> $LOG
sudo systemctl restart guacd  >> $LOG

sudo cp logo-64.png /usr/share/lxde/images/lxde-icon.png  >> $LOG
sudo wget https://avx-build.s3.eu-central-1.amazonaws.com/cne-student.pem -P /home/ubuntu/  >> $LOG
sudo chmod 400 /home/ubuntu/cne-student.pem  >> $LOG
sudo chown ubuntu:ubuntu /home/ubuntu/cne-student.pem  >> $LOG

# Add pod ID search domain
sudo sed -i '$d' /etc/netplan/50-cloud-init.yaml  >> $LOG
echo "            nameservers:
                search: [$4.$5]" | sudo tee -a /etc/netplan/50-cloud-init.yaml
sudo netplan apply  >> $LOG