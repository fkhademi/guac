#!/bin/bash
#set -e
# sh test frey frey pod1.avxlab.cc pod1 avxlab.cc
# Arguments:  1=username 2=password 3=fqdn 4=pod_id 5=domain_name

LOG="/tmp/guac-install.log"

# Remove apache2
apt autoremove -y
apt-get remove apache2 -y

# Install all the needed packages
sudo apt-get update
sudo apt-get install xrdp lxde make gcc g++ libcairo2-dev libjpeg-turbo8-dev libpng-dev libtool-bin libossp-uuid-dev libavcodec-dev libavutil-dev libswscale-dev freerdp2-dev libpango1.0-dev libssh2-1-dev libvncserver-dev libtelnet-dev libssl-dev libvorbis-dev libwebp-dev tomcat9 tomcat9-admin tomcat9-common tomcat9-user nginx -y

# Start and enable Tomcat
sudo systemctl start tomcat9
sudo systemctl enable tomcat9

# Download and install Guacamole Server
wget https://downloads.apache.org/guacamole/1.1.0/source/guacamole-server-1.1.0.tar.gz -P /tmp/
tar xzf /tmp/guacamole-server-1.1.0.tar.gz -C /tmp/

(
    cd /tmp/guacamole-server-1.1.0 
    sudo ./configure --with-init-dir=/etc/init.d
    sudo make
    sudo make install
    sudo ldconfig
)

sudo systemctl start guacd
sudo systemctl enable guacd 


####
sudo mkdir /etc/guacamole

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


sudo wget https://downloads.apache.org/guacamole/1.1.0/binary/guacamole-1.1.0.war -O /etc/guacamole/guacamole.war 
sudo ln -s /etc/guacamole/guacamole.war /var/lib/tomcat9/webapps/ 
sleep 10 
sudo mkdir /etc/guacamole/{extensions,lib} 
sudo bash -c 'echo "GUACAMOLE_HOME=/etc/guacamole" >> /etc/default/tomcat9'

echo "guacd-hostname: localhost
guacd-port:    4822
user-mapping:    /etc/guacamole/user-mapping.xml
auth-provider:    net.sourceforge.guacamole.net.basic.BasicFileAuthenticationProvider"  | sudo tee -a /etc/guacamole/guacamole.properties

sudo ln -s /etc/guacamole /usr/share/tomcat9/.guacamole

sudo systemctl restart tomcat9 
sudo systemctl restart guacd 

#####
# Create user for RDP session
sudo useradd -m -s /bin/bash $1 
echo "$1:$2" | sudo chpasswd

# Download ssl cert for nginx
sudo wget https://avx-build.s3.eu-central-1.amazonaws.com/avxlab.de-cert.crt -O /etc/nginx/cert.crt #san-cert.crt 
sudo wget https://avx-build.s3.eu-central-1.amazonaws.com/avxlab.de-cert.key -O /etc/nginx/cert.key #san-cert.key 
sudo systemctl start nginx 
sudo systemctl enable nginx 

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

sudo chown $1:$1 /home/$1/Desktop 
sudo chown $1:$1 /home/$1/Desktop/* 

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

sudo systemctl restart nginx 

# Customize Guacamole login page
sudo ls -l /var/lib/tomcat9/webapps/guacamole/ 
sudo wget https://avx-build.s3.eu-central-1.amazonaws.com/logo-144.png 
sudo wget https://avx-build.s3.eu-central-1.amazonaws.com/logo-64.png 
# while [ ! -d /var/lib/tomcat9/webapps/guacamole/images/ ]; do
#   sleep 1
# done
sudo cp logo-144.png /var/lib/tomcat9/webapps/guacamole/images/ 
sudo cp logo-64.png /var/lib/tomcat9/webapps/guacamole/images/ 
sudo cp logo-144.png /var/lib/tomcat9/webapps/guacamole/images/guac-tricolor.png 
sudo sed -i "s/Apache Guacamole/Aviatrix Build - $4/g" /var/lib/tomcat9/webapps/guacamole/translations/en.json 
sudo systemctl restart tomcat9 
sudo systemctl restart guacd 

sudo cp logo-64.png /usr/share/lxde/images/lxde-icon.png 
sudo wget https://avx-build.s3.eu-central-1.amazonaws.com/cne-student.pem -P /home/ubuntu/ 
sudo chmod 400 /home/ubuntu/cne-student.pem 
sudo chown ubuntu:ubuntu /home/ubuntu/cne-student.pem 

# Add pod ID search domain
sudo sed -i '$d' /etc/netplan/50-cloud-init.yaml 
echo "            nameservers:
                search: [$4.$5]" | sudo tee -a /etc/netplan/50-cloud-init.yaml
sudo netplan apply 