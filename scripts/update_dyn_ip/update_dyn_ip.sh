#!/bin/bash
# This script can be used to update security groups when you use dynamic IP address. You need to set a unique key in the cidr description to use it.
#       "IpRanges": [
#        {
#          "Description": "my-home-dynamic-uid1234",
#          "CidrIp": "178.122.219.198/32"
#        }
#
# update the following value as you need:
base=~
if [ -f "${base}/.awstricks-env" ];
then
    . "${base}/.awstricks-env"
else
    echo "The environment file <~/.awstricks-env> not found. Please, initiate your environment file."
    echo -n -e "Your unique key (my-home-dynamic-uid1234): ";read ukey
    echo -n -e "Default log file (/var/log/dynupd.log): ";read logfile
    touch "${base}/.awstricks-env"
    echo "n=${ukey}" >> "${base}/.awstricks-env"
    echo "log=${logfile}" >> "${base}/.awstricks-env"
    echo "Environment file has been updated succesfully"
    . "${base}/.awstricks-env"
fi
# checking requirements
if [ $# -ne 1 ]; then echo "Use AWS profile as arg: update-dyn-ip <profilename>"; if [ -f ~/.aws/credentials ]; then echo "Available profiles:"; cat ~/.aws/credentials|grep -E '\[.*\]'|grep -v \#|sed -e 's/\[/ /;s/\]//;'; fi; exit; fi;
if ! [ -w "${log}" ]; then echo "Permissions denied. Make sure the file ${log} is writable"; exit; fi;
jq --version 2>/dev/null > /dev/null; if [ $? -ne 0 ]; then echo "jq is required, but not found in the system. Make sure it is installed"; exit; fi;
aws --version 2>/dev/null > /dev/null; if [ $? -ne 0 ]; then echo "aws-cli is required, but not found in the system. Make sure it is installed"; exit; fi;
#
profile=$1
a="aws --profile=${profile}"
echo -e "====================\n["$(date +%Y-%m-%d-%H:%M:%S)"] Updating dynamic IP address in security groups" |tee -a "${log}"
echo -n -e "The keyword used: ${n}. \e[31mConfirm it is unique (y/n):\e[0m "; read yesno
if [ "${yesno}" != "y" -a "${yesno}" != "Y" ]; then echo "Exiting.."; exit; fi;
m=`curl -s ifconfig.io`
echo -e "My ip: ${m}" |tee -a "${log}"
l=`$a ec2 describe-security-groups`
echo "${l}"|jq -r '.SecurityGroups[]|select(.IpPermissions[].IpRanges[].Description == "'${n}'").GroupId'|sort|uniq|while read sgid;
do
  frprs=`echo "${l}"|jq -r '.SecurityGroups[]|select(.GroupId == "'${sgid}'")|.IpPermissions[]|select(.IpRanges[].Description == "'${n}'").FromPort'|sort|uniq`
  echo "${frprs}"|while read frpr;
  do
    if ! [[ "$frpr" =~ ^[0-9]+$ ]];
    then
      echo "Invalid port number: ${frpr} for SG: ${sgid}"
    else
      cidrs=`echo "${l}"|
            jq -r '.SecurityGroups[]|select(.IpPermissions[].IpRanges[].Description == "'${n}'" and .GroupId == "'${sgid}'")|.IpPermissions[]|select(.IpRanges[].Description == "'${n}'" and .FromPort == '${frpr}')|.IpRanges[]|select(.Description == "'${n}'").CidrIp'|\
            sort|uniq`
      if [ $(echo "${cidrs}"|wc -l) -gt 1 ]; then echo -e "\e[1;49;31mNote: you have more than 1 IP in the same SG with unique description\e[0m."; fi;
      echo "${cidrs}"|while read cidr;
      do
        if [ "${cidr}" != "${m}/32" ];
        then
          echo "["$(date +%Y-%m-%d-%H:%M:%S)"] Updating SG: ${sgid} / Port: ${frpr} / cidr: ${cidr}" |tee -a "${log}"
          #echo -n -e "\e[31mConfirm (y/n):\e[0m ";
          #read -n 1 yesno
          #echo "read: $yesno"
          yesno="y"
          if [ "${yesno}" != "y" -a "${yesno}" != "Y" ];
          then
            echo "["$(date +%Y-%m-%d-%H:%M:%S)"] cidr updating has been skipped by user" | tee -a "${log}"
          else
            echo "["$(date +%Y-%m-%d-%H:%M:%S)"] >> ec2 revoke-security-group-ingress --group-id \"${sgid}\" --protocol tcp --port \"${frpr}\" --cidr \"${cidr}\"" |tee -a "${log}"
            $a ec2 revoke-security-group-ingress --group-id "${sgid}" --protocol tcp --port "${frpr}" --cidr "${cidr}"
            # note: here we assume that ToPort will be the same as FromPort
            echo "["$(date +%Y-%m-%d-%H:%M:%S)"] >> ec2 authorize-security-group-ingress --group-id \"${sgid}\" --ip-permissions IpProtocol=tcp,FromPort=\"${frpr}\",ToPort=\"${frpr}\",IpRanges='[{CidrIp=${m}/32,Description=\"${n}\"}]'" |tee -a "${log}"
            $a ec2 authorize-security-group-ingress --group-id "${sgid}" --ip-permissions IpProtocol=tcp,FromPort="${frpr}",ToPort="${frpr}",IpRanges='[{CidrIp='${m}/32',Description="'${n}'"}]'
          fi;
        fi;
      done;
    fi;
  done;
done;
echo "Log saved at ${log}"
