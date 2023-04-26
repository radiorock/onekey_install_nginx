#!/bin/bash

check_os() {
  if [ -f /etc/debian_version ]; then
    OS="debian"
    echo "Detected Debian OS ..."
  elif [ -f /etc/lsb-release ]; then
    OS="ubuntu"
    echo "Detected Ubuntu OS ..."
  else
    echo "Unsupported operating system."
    exit 1
  fi
}

get_server_public_ip() {
  echo "Getting server's public IP address ..."
  SERVER_IP=$(wget -t 3 -T 15 -qO- https://ipv4.icanhazip.com)
  echo "Server's public IP address: $SERVER_IP"
}

install_dependencies() {
  echo "Updating package list ..."
  apt-get update

  echo "Installing dependencies ..."
  apt-get install -y build-essential libpcre3 libpcre3-dev libssl-dev zlib1g-dev wget
}

install_nginx() {
  echo "Downloading and extracting Nginx source ..."
  cd /opt
  wget https://nginx.org/download/nginx-1.18.0.tar.gz
  tar -zxvf nginx-1.18.0.tar.gz
  cd nginx-1.18.0

  echo "Compiling and installing Nginx ..."
  ./configure --with-http_ssl_module
  make
  make install
}

configure_vhost() {
  echo "Configuring Nginx virtual host ..."

  cat > /usr/local/nginx/conf/nginx.conf <<EOF
worker_processes  1;

events {
    worker_connections  1024;
}

http {
  upstream backend {
    server 127.0.0.1:8000;
  }

  server {
    listen 80;
    server_name example.com;

    location / {
      proxy_pass http://backend;
      proxy_set_header Host \$host;
      proxy_set_header X-Real-IP \$remote_addr;
      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
  }
}
EOF

  echo "Creating vhost directory ..."
  mkdir -p /usr/local/nginx/html/example.com

  echo "Configuring SSL ..."
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /usr/local/nginx/conf/server.key -out /usr/local/nginx/conf/server.crt -subj "/C=US/ST=CA/L=Los Angeles/O=Example/OU=IT Department/CN=example.com"

  echo "Starting Nginx ..."
  /usr/local/nginx/sbin/nginx

  echo "Nginx successfully started."
}

check_os
get_server_public_ip
install_dependencies
install_nginx
configure_vhost

