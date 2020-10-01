#!/bin/bash

# Script that shows some AWS resource usage
# Requires AWS and jq packets
# Variables are stored in settings.conf file, which must be placed in the same 
# directory

RED="\e[41m"
GREEN="\e[42m"
BLUE="\e[44m"
RESET="\e[0m"

export LC_NUMERIC="en_US.UTF-8"
error(){
  echo -e "${RED}$1${RESET}"
}
success() {
  echo -e "${GREEN} $1 loaded.. OK${RESET}"
}

loading_modules() {
  if [[ -f $DIR/$1 ]]; then
    source $DIR/$1
    success $1
  else
    error "ERROR WHILE LOADING $1"
  fi
}

DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then 
  DIR="$PWD"; 
fi

loading_modules orphaned_elastic_ips.sh
loading_modules ebs_volumes.sh
loading_modules aged_ebs_snapshots.sh
loading_modules orphaned_ebs_snapshots.sh
loading_modules aged_rds_snapshots.sh
loading_modules orphaned_elb.sh
loading_modules expired_certificates.sh

# Retrieve settings from settings.conf file. Otherwise, use default values
if [[ -f settings.conf ]]; then
  printf "Settings file found, use its parameters\n"
  source settings.conf
else
  printf "Settings settings.conf not found. Use default parameters\n"
  AWS_CLI_PROFILE=default
  AWS_EIP_PRICE="3.6"
  AWS_EBS_gp2_PRICE="0.1"
  AWS_EBS_io1_PRICE="0.125"
  AWS_EBS_st1_PRICE="0.045"
  AWS_EBS_sc1_PRICE="0.025"
  AWS_EBS_mag_PRICE="0.05"
  AWS_SNAP_PRICE="0.05"
  AWS_DB_SNAP_PRICE="0.095"
  AWS_EBS_SNAP_DAYS=90
  AWS_DB_SNAP_DAYS=90
fi

# Counting and showing list of orphaned Elastic IPs.
checking_orphaned_ips

# Counting and showing list of orphaned EBS Volumes.
counting_orphaned_ebs_volumes

# Counting and showing list of aged EBS Snapshots.
counting_aged_ebs_snapshot

# Counting and showing list of orphaned EBS Snapshots.
counting_orphaned_ebs_snapshots

# Counting and showing list of aged RDS Snapshots.
counting_aged_rds_snapshots

# Counting and showing list of Orphaned Load Balancers.
counting_orphaned_elb

# Counting and showing list of expired certificates.
showing_list_of_expired_certificate
