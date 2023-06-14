#!/bin/bash

if ((${EUID:-0} || "$(id -u)")); then
    echo Please run this script as root or using sudo. Script execution aborted.
    exit 1
fi

# Set default values for options and variables
force_confirm_needed=false
confirm_needed=true

# Parse command-line options
while getopts "yw:" opt; do
  case "${opt}" in
    y)
      force_confirm_needed=true
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

## Update and upgrade
sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y

## Install basic package
sudo apt-get install dpkg unzip zip wget -y

## Install postgresql
sudo apt-get install postgresql-14 -y
sudo systemctl enable postgresql.service

## Install python 3.10
sudo apt-get install build-essential python3.10 python3.10-full python3-pip python3-dev python3-venv python3-wheel libxml2-dev libpq-dev libjpeg8-dev liblcms2-dev libxslt1-dev zlib1g-dev libsasl2-dev libldap2-dev build-essential git libssl-dev libffi-dev libmysqlclient-dev libjpeg-dev libblas-dev libatlas-base-dev -y

## Install python certbot
sudo apt-get install python3-certbot-nginx -y

## Install wkhtmltopdf
wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.jammy_amd64.deb
sudo apt-get install ./wkhtmltox_0.12.6.1-2.jammy_amd64.deb -y
sudo rm wkhtmltox_0.12.6.1-2.jammy_amd64.deb
sudo wkhtmltopdf -V

# Deploy user
sudo adduser --system --quiet --disabled-password --group deploy
mkdir /home/deploy/.ssh
chmod 700 /home/deploy/.ssh
touch /home/deploy/.ssh/authorized_keys
chmod 600 /home/deploy/.ssh/authorized_keys
chown deploy:deploy -R /home/deploy/.ssh
sudo mkdir /home/deploy/scripts
sudo chown -R deploy:deploy /home/deploy/scripts
touch /etc/sudoers.d/deploy
echo "deploy ALL=(ALL) NOPASSWD: /bin/mv, /bin/sed, /bin/rm, /bin/chmod, /bin/chown" > /etc/sudoers.d/deploy
sudo ssh-keygen -q -t rsa -b 4096 -f /home/deploy/.ssh/id_rsa -N "" && sudo cat /home/deploy/.ssh/id_rsa.pub >> /home/deploy/.ssh/authorized_keys
echo -e "\nSSH private key for the deploy user"
sudo cat /home/deploy/.ssh/id_rsa
sudo rm /home/deploy/.ssh/id_rsa 
sudo rm /home/deploy/.ssh/id_rsa.pub