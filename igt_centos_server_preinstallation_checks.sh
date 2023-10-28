#!/bin/bash

# Script:       IGT CentOS Server Pre-installation Checks
# Author:       Barker, Griffeth (barkergriffeth@gmail.com)
# Created:      2023-06-27
# Last Updated: 2023-06-27
# Last Change:  Change OS release to CentOS release, add
#               check for docker-compose version. 
#
# Usage: Call this script from your environment's terminal and provide
# input if prompted.
#
# Options: None.
#
# Notes: This script gathers facts about the server so IGT can verify
# if the server meets their requirements for software intsallation.
#
# I am not affiliated with nor sponsored by IGT (International Game
# Technologies). This is just a script I came up with because I've
# gone through so many installation and upgarde projects with them
# as a customer, and during the pre-installation phase of the project,
# they always ask for this information once the CentOS servers have
# become available.
#
# This was one of the first bash script I ever wrote, and I'm
# committing this version of it as a bit of personal history. I most 
# certainly intend to rewrite this to be much better, as there are some
# less-than-correct ways of doing things present.

# Variables
REPORT_FILE=/home/igt_admin/ivt.report
REPORT_DATE=$(date +%Y-%m-%d)

# Welcome
clear
echo "########################################################################"
echo "# PRE-VALIDATION REPORT FOR IGT LINUX SERVER DEPLOYMENT                #"
echo "#                                                                      #"
echo "# ORGANIZATION:     Jacobs Entertainment, Incorporated                 #"
echo "# AUTHOR:           Barker, Griffeth (gbarker@bhwk.com)                #"
echo "# VERSION:          1.1                                                #"
echo "# LAST UPDATED:     2023-06-27                                         #"
echo "# LAST CHANGE:      Change OS release to CentOS release, add           #"
echo "#                   check for docker-compose version.                  #"
echo "#                                                                      #"
echo "# REPORT GENERATED: "$REPORT_DATE"                                         #"
echo "########################################################################"
echo " "
echo "Creating report file..."
sudo touch $REPORT_FILE
echo "Gathering facts..."

# Report header
echo "########################################################################" >> $REPORT_FILE
echo "# PRE-VALIDATION REPORT FOR IGT LINUX SERVER DEPLOYMENT                #" >> $REPORT_FILE
echo "#                                                                      #" >> $REPORT_FILE
echo "# ORGANIZATION:     Jacobs Entertainment, Incorporated                 #" >> $REPORT_FILE
echo "# AUTHOR:           Barker, Griffeth (gbarker@bhwk.com)                #" >> $REPORT_FILE
echo "# VERSION:          1.1                                                #" >> $REPORT_FILE
echo "# LAST UPDATED:     2023-06-27                                         #" >> $REPORT_FILE
echo "# LAST CHANGE:      Change OS release to CentOS release, add           #" >> $REPORT_FILE
echo "#                   check for docker-compose version.                  #" >> $REPORT_FILE
echo "#                                                                      #" >> $REPORT_FILE
echo "# REPORT GENERATED: "$REPORT_DATE"                                         #" >> $REPORT_FILE
echo "########################################################################" >> $REPORT_FILE
echo " " >> $REPORT_FILE >> $REPORT_FILE

# Operating system information
echo " - Getting operating system information..."
echo "########################################################################" >> $REPORT_FILE
echo "# OPERATING SYSTEM INFORMATION                                         #" >> $REPORT_FILE
echo "########################################################################" >> $REPORT_FILE
cat /etc/centos-release >> $REPORT_FILE
echo " " >> $REPORT_FILE

# Processor information
echo " - Getting processor information..."
echo "########################################################################" >> $REPORT_FILE
echo "# PROCESSOR INFORMATION                                                #" >> $REPORT_FILE
echo "########################################################################" >> $REPORT_FILE
cat /proc/cpuinfo >> $REPORT_FILE
echo " " >> $REPORT_FILE

# Memory information
echo " - Getting memory information..."
echo "########################################################################" >> $REPORT_FILE
echo "# MEMORY INFORMATION                                                   #" >> $REPORT_FILE
echo "########################################################################" >> $REPORT_FILE
free >> $REPORT_FILE
echo " " >> $REPORT_FILE

# Disk information
echo " - Getting disk information..."
echo "########################################################################" >> $REPORT_FILE
echo "# DISK INFORMATION                                                     #" >> $REPORT_FILE
echo "########################################################################" >> $REPORT_FILE
df -H >> $REPORT_FILE
echo " " >> $REPORT_FILE

# Docker information
echo " - Getting docker information..."
echo "########################################################################" >> $REPORT_FILE
echo "# DOCKER INFORMATION                                                   #" >> $REPORT_FILE
echo "########################################################################" >> $REPORT_FILE
docker -v >> $REPORT_FILE
# Create a link to the docker-compose binary per IGT systems engineers' instructions
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
docker-compose --version >> $REPORT_FILE
echo " " >> $REPORT_FILE

# Network information
echo " - Getting network information..."
echo "########################################################################" >> $REPORT_FILE
echo "# NETWORK INFORMATION                                                  #" >> $REPORT_FILE
echo "########################################################################" >> $REPORT_FILE
ip addr show >> $REPORT_FILE
echo " " >> $REPORT_FILE

# Block devices information
echo " - Getting block device information..."
echo "########################################################################" >> $REPORT_FILE
echo "# BLOCK DEVICES INFORMATION                                            #" >> $REPORT_FILE
echo "########################################################################" >> $REPORT_FILE
lsblk >> $REPORT_FILE
echo " " >> $REPORT_FILE

# End
echo "Done gathering facts."
echo " "
echo "The script has completed." 
echo "You can find the report at" $REPORT_FILE "."
echo " "
