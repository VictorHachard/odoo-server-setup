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

#----------------------------------------------------------------------------------------------------
# Stop the script if the script is not run as root or using sudo
#----------------------------------------------------------------------------------------------------
if ((${EUID:-0} || "$(id -u)")); then
    echo Please run this script as root or using sudo, the script will stop here.
    exit 0
fi

OE_USER=""

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

echo -e "\n${GREEN}==== Prepare tmp ====${NC}"
rm -rf $DEPLOYER_HOME/$OE_USER/tmp
mkdir -p $DEPLOYER_HOME/$OE_USER/tmp
sudo unzip -q $DEPLOYER_HOME/build-src-$OE_USER.zip -d $DEPLOYER_HOME/$OE_USER/tmp
sudo chown -R $OE_USER:$OE_USER $DEPLOYER_HOME/$OE_USER/tmp

echo -e "\n${GREEN}==== Stop the Odoo service ====${NC}"
sudo systemctl stop $OE_USER.service

echo -e "\n${GREEN}==== Move code ====${NC}"
sudo rm -rf $OE_HOME_EXT/src/odoo
sudo rm -f $OE_HOME_EXT/src/odoo-bin
sudo mv $DEPLOYER_HOME/$OE_USER/tmp/* $OE_HOME_EXT/src

echo -e "\n${GREEN}==== Start the Odoo service ====${NC}"
sudo systemctl start $OE_USER.service

echo -e "\n${GREEN}The deployment of the source code is finish.${NC}"
