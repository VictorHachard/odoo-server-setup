#!/bin/bash

if ((${EUID:-0} || "$(id -u)")); then
    echo "Please run this script as root or using sudo. Script execution aborted."
    exit 1
fi

# Set default values for options and variables
declare -A env_map
declare -A user_map
declare -A port_map
declare -A longpolling_port_map

# Check if Nginx is installed
if ! command -v nginx >/dev/null 2>&1; then
    echo "Nginx is not installed. Exiting..."
    exit 1
fi

# Check if PostgreSQL is installed
if ! command -v psql >/dev/null 2>&1; then
    echo "PostgreSQL is not installed. Exiting..."
    exit 1
fi

# Initialize maps using a loop
for i in {0..9}; do
  env_var=$(printf \\$(printf '%03o' $((97 + i))))  # Convert to a, b, c, ...
  env_map[$env_var]=$(printf "%s" $env_var | tr '[:lower:]' '[:upper:]')
  user_map[$env_var]=$env_var
  port_map[$env_var]=$((8069 + i * 2))
  longpolling_port_map[$env_var]=$((8072 + i * 2))
done

# Loop through environments and set up everything
for env_var in "${!env_map[@]}"; do
  env_var_value_nice="${env_map[$env_var]}"
  user_name="odoo-${user_map[$env_var]}"
  OE_PORT="${port_map[$env_var]}"
  LONGPOLLING_PORT="${longpolling_port_map[$env_var]}"
  WEBSITE_NAME="$env_var.bizzdev.net"

  # Create odoo user
  sudo adduser --system --quiet --shell=/bin/bash --home="/opt/odoo/${user_name}" --gecos 'ODOO' --group $user_name
  sudo -u "$user_name" bash -c "echo 'export ODOO_ENV=\"$env_var_value_nice\"' >> ~/.bashrc"
  sudo mkdir /opt/odoo/$user_name/.local
  sudo chown $user_name:$user_name /opt/odoo/$user_name/.local
  sudo mkdir /var/log/$user_name
  sudo chown $user_name:$user_name /var/log/$user_name
  sudo mkdir /var/backups/$user_name
  sudo chown $user_name:$user_name /var/backups/$user_name
  sudo mkdir -p "/opt/odoo/${user_name}/src"
  sudo chown -R $user_name:$user_name "/opt/odoo/${user_name}"/*

  sudo mkdir "/home/deploy/scripts/${user_name}"
  sudo chown deploy:deploy "/home/deploy/scripts/${user_name}"
  sudo echo "$(cat /etc/sudoers.d/deploy), /home/deploy/scripts/${user_name}/deploy-config.sh, /home/deploy/scripts/${user_name}/deploy-custom-app.sh, /home/deploy/scripts/${user_name}/deploy-src.sh" > /etc/sudoers.d/deploy

  # Create postgres odoo user
  sudo -i -u postgres psql -c "CREATE USER \"${user_name}\" CREATEDB;"

  # Update psql config
  sudo sed -i "/# Database administrative login by Unix domain socket/i host    all    ${user_name}    127.0.0.1/32    trust" /etc/postgresql/14/main/pg_hba.conf
  sudo systemctl restart postgresql
  
  # Create odoo service
  OE_HOME_EXT_CODE="/opt/odoo/${user_name}/src"
  OE_CONFIG_FILES="/opt/odoo/${user_name}/src/environment/configurations"

  cat <<EOF > ~/$user_name.service
[Unit]
Description=Odoo ($user_name)
Requires=postgresql.service
After=network.target postgresql.service

[Service]
Type=simple
SyslogIdentifier=$user_name
PermissionsStartOnly=true
User=$user_name
Group=$user_name
RemainAfterExit=yes
EnvironmentFile=/opt/odoo/$user_name/.bashrc
ExecStart=/opt/odoo/${user_name}/.virtualenv-${user_name}/bin/python $OE_HOME_EXT_CODE/odoo-bin --config=$OE_CONFIG_FILES/${user_name,,}.conf

[Install]
WantedBy=multi-user.target
EOF

  sudo mv ~/$user_name.service /etc/systemd/system
  sudo chmod 755 /etc/systemd/system/$user_name.service
  sudo chown root: /etc/systemd/system/$user_name.service

  sudo systemctl enable $user_name.service

  # Create odoo nginx
  sudo mkdir /var/www/$user_name
  cat <<EOF > ~/$user_name
map \$http_upgrade \$connection_upgrade {
  default upgrade;
  ''      close;
}

#server {
#  listen 80;
#  listen [::]:80;
#  server_name $WEBSITE_NAME;
#  return 301 https://\$host\$request_uri;
#}

server {
  listen 80;
  #listen 443 ssl http2;
  #listen [::]:443 ssl http2;
  #ssl_certificate ;
  #ssl_certificate_key ;

  server_name $WEBSITE_NAME;
  root /var/www/html;

  proxy_set_header X-Forwarded-Host \$host;
  proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto \$scheme;
  proxy_set_header X-Real-IP \$remote_addr;
  add_header X-Frame-Options "SAMEORIGIN";
  add_header X-XSS-Protection "1; mode=block";
  proxy_set_header X-Client-IP \$remote_addr;
  proxy_set_header HTTP_X_FORWARDED_HOST \$remote_addr;

  access_log /var/log/nginx/$user_name-access.log;
  error_log /var/log/nginx/$user_name-error.log;

  client_max_body_size 4000M;

  proxy_read_timeout 900s;
  proxy_connect_timeout 900s;
  proxy_send_timeout 900s;

  proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;

  location / {
    proxy_pass http://127.0.0.1:$OE_PORT;
    proxy_redirect off;
    proxy_max_temp_file_size 0;
  }

  location /websocket {
    proxy_pass http://127.0.0.1:$LONGPOLLING_PORT;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \$connection_upgrade;
    proxy_set_header X-Forwarded-Host \$http_host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Real-IP \$remote_addr;
  }

  location ~* .(js|css)$ {
    expires 2d;
    proxy_pass http://127.0.0.1:$OE_PORT;
    add_header Cache-Control "public, no-transform";
  }

  location ~* .(png|jpg|jpeg|gif|ico)$ {
    expires 30d;
    proxy_pass http://127.0.0.1:$OE_PORT;
    add_header Cache-Control "public, no-transform";
  }

  location = /robots.txt {
    return 200 "User-agent: *\nDisallow: /\n";
  }

  gzip_types text/css text/less text/plain text/xml application/xml application/json application/javascript application/pdf image/jpeg image/png;
  gzip on;
}
EOF

  sudo mv ~/$user_name /etc/nginx/sites-available/
  sudo ln -s /etc/nginx/sites-available/$user_name /etc/nginx/sites-enabled/$user_name

done

sudo nginx -s reload