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

# Check if Nginx is installed
if ! command -v nginx >/dev/null 2>&1; then
    echo "Nginx is not installed. Exiting..."
    exit 1
fi

## Update and upgrade
sudo apt update && sudo apt upgrade -y && sudo apt autoremove -y

## Install docker
sudo apt-get install ca-certificates curl gnupg lsb-release -y
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install docker-ce docker-ce-cli containerd.io -y

## Install seq
sudo mkdir /opt/seq-data
sudo docker pull datalust/seq
sudo docker run --name seq -d --restart always -e ACCEPT_EULA=Y --memory="2048m" --memory-swap=0 --cpus="0.2" -v /opt/seq-data:/data -p 8080:80 -p 5341:5341 -p 12201:12201/udp datalust/seq
