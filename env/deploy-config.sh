#!/bin/bash
####################################################################################################
# Script for deploying the code on server.
# Author: Hachard Victor
#
# If the file come from windows, run -> sudo sed -i -e 's/\r$//' deploy-src.sh
####################################################################################################
# Complete the following variables for your Odoo deployment and check the script for hardcoded values!

DEPLOYER_HOME="/home/deploy"

####################################################################################################

RED='\033[0;31m'          # Red
GREEN='\033[0;32m'        # Green
NC='\033[0m'              # No Color

if ((${EUID:-0} || "$(id -u)")); then
    echo Please run this script as root or using sudo, the script will stop here.
    exit 0
fi

while getopts "o:" opt; do
  case "${opt}" in
    o)
      OE_USER="${OPTARG}"
      ;;
  esac
done

while [ -z "$OE_USER" ]; do
  read -p "Enter a username: " OE_USER
done

OE_HOME_EXT="/opt/odoo/${OE_USER}"

echo -e "\n${GREEN}==== Stop the Odoo service ====${NC}"
sudo systemctl stop $OE_USER.service

echo -e "\n${GREEN}==== Reinstall the requirements ====${NC}"
if [ ! -d "$OE_HOME_EXT/.virtualenv-$OE_USER" ]; then
    sudo -u $OE_USER python3.7 -m venv $OE_HOME_EXT/.virtualenv-$OE_USER
fi

sudo -u $OE_USER bash -c "source $OE_HOME_EXT/.virtualenv-$OE_USER/bin/activate && \
                            pip3.7 install --upgrade pip && \
                            pip3.7 install wheel && \
                            pip3.7 install -r $OE_HOME_EXT/src/requirements.txt && \
                            deactivate"

echo -e "\n${GREEN}==== Start the Odoo service ====${NC}"
sudo systemctl start $OE_USER.service

echo -e "\n${GREEN}Done! The deployment of the source code is finish.${NC}"
