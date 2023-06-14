#!/bin/bash

if ((${EUID:-0} || "$(id -u)")); then
    echo Please run this script as root or using sudo. Script execution aborted.
    exit 1
fi

# Set default values for options and variables
declare -A env_map=(["p"]="PROD" ["c"]="CERT" ["d"]="DEV")
force_confirm_needed=false
confirm_needed=true
user_name=""
env_var_value=""
LONGPOLLING_PORT=""
OE_PORT=""
WEBSITE_NAME=""

# Parse command-line options
while getopts "ye:o:p:lp:w:" opt; do
  case "${opt}" in
    y)
      force_confirm_needed=true
      ;;
    e)
      if [[ "${OPTARG}" == "p" || "${OPTARG}" == "c" || "${OPTARG}" == "d" ]]; then
        env_var_value="${OPTARG}"
        env_var_value_nice="${env_map[$env_var_value]}"
      else
        echo "Invalid option argument for -e: ${OPTARG}" >&2
        exit 1
      fi
      ;;
    o)
      user_name="${OPTARG}"
      ;;
    p)
      OE_PORT="${OPTARG}"
      ;;
    lp)
      LONGPOLLING_PORT="${OPTARG}"
      ;;
    w)
      WEBSITE_NAME="${OPTARG}"
      ;;
  esac
done

# Check if confirmation is needed
if $force_confirm_needed; then
  confirm_needed=false
fi

# Prompt for confirmation if needed
if $confirm_needed; then
  read -p "This script will update and configure your instance. Do you wish to proceed? (y/n) " confirm
  if [ "$confirm" != "y" ]; then
    echo "Script execution aborted."
    exit 1
  fi
fi

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

# Prompt for required information
while [ -z "$user_name" ]; do
  read -p "Enter a username (note that 'odoo-' is added as a prefix): " user_name
done

while [[ ! "$env_var_value" =~ ^(p|c|d)$ ]]; do
  read -p "Enter the environment (p - Production, c - Certification, d - Test): " env_var_value
  env_var_value_nice="${env_map[$env_var_value]}"
done

while [[ ! "$OE_PORT" =~ ^[0-9]+$ ]]; do
  read -p "Enter the Odoo port number: " OE_PORT
done

while [[ ! "$LONGPOLLING_PORT" =~ ^[0-9]+$ ]]; do
  read -p "Enter the Long Polling port number: " LONGPOLLING_PORT
done

while [ -z "$WEBSITE_NAME" ] || [[ ! "$WEBSITE_NAME" =~ ^[a-zA-Z0-9.-]+$ ]]; do
  read -p "Enter the website name for the Nginx server: " WEBSITE_NAME
done

user_name="odoo-${user_name}"

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
echo ", /home/deploy/scripts/${user_name}/deploy-config.sh, /home/deploy/scripts/${user_name}/deploy-custom-app.sh, /home/deploy/scripts/${user_name}/deploy-src.sh" >> /etc/sudoers.d/deploy

# Create postgres odoo user
sudo -i -u postgres psql -c "CREATE USER \"${user_name}\" CREATEDB;"

# Update psql config


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
ExecStart=/opt/odoo/${user_name}/.virtualenv-$OE_USER/bin/python $OE_HOME_EXT_CODE/odoo-bin --config=$OE_CONFIG_FILES/${user_name,,}.conf

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
server {
  listen 80;
  listen [::]:80;
  server_name $WEBSITE_NAME;
  return 301 https://\$host\$request_uri;
}

server {
  listen 443 ssl http2;
  listen [::]:443 ssl http2;
  ssl_certificate ;
  ssl_certificate_key ;

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

  client_max_body_size 1000M;

  proxy_buffers 16 64k;
  proxy_buffer_size 128k;
  proxy_read_timeout 900s;
  proxy_connect_timeout 900s;
  proxy_send_timeout 900s;

  proxy_next_upstream error timeout invalid_header http_500 http_502
  http_503;

  types {
    text/less less;
    text/scss scss;
  }

  gzip on;
  gzip_min_length 1100;
  gzip_buffers 4 32k;
  gzip_types text/css text/less text/plain text/xml application/xml application/json application/javascript application/pdf image/jpeg image/png;
  gzip_vary on;
  client_header_buffer_size 4k;
  large_client_header_buffers 4 64k;

  location / {
    proxy_pass http://127.0.0.1:$OE_PORT;
    proxy_redirect off;
    proxy_max_temp_file_size 0;
  }

  location /longpolling {
    proxy_pass http://127.0.0.1:$LONGPOLLING_PORT;
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
  
EOF

# Add the conditionally block if not prod
if [ $env_var_value != "p" ]; then
    echo '  location = /robots.txt {' >> ~/$user_name
    echo '    return 200 "User-agent: *\nDisallow: /\n";' >> ~/$user_name
    echo '  }' >> ~/$user_name
fi

echo '}' >> ~/$user_name

sudo mv ~/$user_name /etc/nginx/sites-available/
sudo ln -s /etc/nginx/sites-available/$user_name /etc/nginx/sites-enabled/$user_name
