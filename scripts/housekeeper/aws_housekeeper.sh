#!/bin/bash

# Script that shows some AWS resource usage
# Requires AWS and jq packets
# Variables are stored in settings.conf file, which must be placed in the same directory

export LC_NUMERIC="en_US.UTF-8"

# Retrieve settings from settings.conf file. Otherwise, use default values
if [[ -f settings.conf ]]; then
    printf "Settings file found, use its parameters\n"
    . settings.conf
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

printf "Checking region ${AWS_REGION}\n"
#Counting and showing list of orphaned Elastic IPs.
printf "\n"
printf "=== Orphaned Elastic IPs ===\n"
AWS_EIP_COUNT=$(aws --region "$AWS_REGION" --profile "$AWS_CLI_PROFILE" ec2 describe-addresses --query 'Addresses[*].[PublicIp, InstanceId]' --output text | grep -c None)

if ((AWS_EIP_COUNT>0)); then
    AWS_EIP_SUMM=$(jq -n "$AWS_EIP_COUNT * $AWS_EIP_PRICE")
    AWS_EIP_LIST=$(aws --region "$AWS_REGION" --profile "$AWS_CLI_PROFILE" ec2 describe-addresses --query 'Addresses[*].{TagName:Tags[0].Key,TagValue:Tags[0].Value,IP:PublicIp,Orphan:InstanceId==null}' --output table | grep -v False)
    printf "You have %s unused IPs, which cost you approximately \$%.2f per month \n" "$AWS_EIP_COUNT" "$AWS_EIP_SUMM"
    printf "These IPs are:\n"
    printf "%s\n" "$AWS_EIP_LIST"
else
    printf "You have no unused IPs"
fi
printf "\n\n"


#Counting and showing list of orphaned EBS Volumes.
# Price is based on volume type.
printf "=== EC2 Elastic Block Store ===\n"
printf "=== Orphaned EBS Volumes ===\n"
AWS_EBS_COUNT=$(aws --region "$AWS_REGION" --profile "$AWS_CLI_PROFILE" ec2 describe-volumes --query 'Volumes[*].[VolumeId, Attachments[0]==null]' --output text | grep -c True)

if ((AWS_EBS_COUNT>0)); then
    AWS_EBS_gp2_SIZE=$(aws --region "$AWS_REGION" --profile "$AWS_CLI_PROFILE" ec2 describe-volumes --query 'Volumes[*].{id:VolumeId,orphan:Attachments[0]==null,type:VolumeType,size:Size}' --output text | grep True | grep gp2 | awk '{s+=$3} END {print s}')
    AWS_EBS_io1_SIZE=$(aws --region "$AWS_REGION" --profile "$AWS_CLI_PROFILE" ec2 describe-volumes --query 'Volumes[*].{id:VolumeId,orphan:Attachments[0]==null,type:VolumeType,size:Size}' --output text | grep True | grep io1 | awk '{s+=$3} END {print s}')
    AWS_EBS_st1_SIZE=$(aws --region "$AWS_REGION" --profile "$AWS_CLI_PROFILE" ec2 describe-volumes --query 'Volumes[*].{id:VolumeId,orphan:Attachments[0]==null,type:VolumeType,size:Size}' --output text | grep True | grep st1 | awk '{s+=$3} END {print s}')
    AWS_EBS_sc1_SIZE=$(aws --region "$AWS_REGION" --profile "$AWS_CLI_PROFILE" ec2 describe-volumes --query 'Volumes[*].{id:VolumeId,orphan:Attachments[0]==null,type:VolumeType,size:Size}' --output text | grep True | grep sc1 | awk '{s+=$3} END {print s}')
    AWS_EBS_mag_SIZE=$(aws --region "$AWS_REGION" --profile "$AWS_CLI_PROFILE" ec2 describe-volumes --query 'Volumes[*].{id:VolumeId,orphan:Attachments[0]==null,type:VolumeType,size:Size}' --output text | grep True | grep standard | awk '{s+=$3} END {print s}')
    AWS_EBS_gp2_SUMM=$(jq -n "${AWS_EBS_gp2_SIZE:=0} * $AWS_EBS_gp2_PRICE")
    AWS_EBS_io1_SUMM=$(jq -n "${AWS_EBS_io1_SIZE:=0} * $AWS_EBS_io1_PRICE")
    AWS_EBS_st1_SUMM=$(jq -n "${AWS_EBS_st1_SIZE:=0} * $AWS_EBS_st1_PRICE")
    AWS_EBS_sc1_SUMM=$(jq -n "${AWS_EBS_sc1_SIZE:=0} * $AWS_EBS_sc1_PRICE")
    AWS_EBS_mag_SUMM=$(jq -n "${AWS_EBS_mag_SIZE:=0} * $AWS_EBS_mag_PRICE")

    AWS_EBS_SUMM=$(jq -n "$AWS_EBS_gp2_SUMM + $AWS_EBS_io1_SUMM + $AWS_EBS_st1_SUMM + $AWS_EBS_sc1_SUMM + $AWS_EBS_mag_SUMM")
    AWS_EBS_LIST=$(aws --region "$AWS_REGION" --profile "$AWS_CLI_PROFILE" ec2 describe-volumes --query 'Volumes[*].{TagName:Tags[0].Key,TagValue:Tags[0].Value,id:VolumeId,orphan:Attachments[0]==null,type:VolumeType,size:Size}' --output table | grep -v False)

    printf "You have total %s unused volumes, which cost you approximately \$%.2f per month \n" "$AWS_EBS_COUNT" "$AWS_EBS_SUMM"
    printf "These volumes are:\n"
    printf "%s\n" "$AWS_EBS_LIST"
else
    printf "You have no unused volumes"
fi
printf "\n\n"


#Counting and showing list of aged EBS Snapshots.
# The age translates into seconds (DAYS * 24 * 60 * 60)
printf "=== Aged EBS Snapshots ===\n"
AWS_EBS_SNAP_AGE=$(($AWS_EBS_SNAP_DAYS * 86400))
AWS_SNAP_DRAFT=$(aws --region "$AWS_REGION" --profile "$AWS_CLI_PROFILE" ec2 describe-snapshots --owner-ids self | jq --arg AGE "$AWS_EBS_SNAP_AGE" '[.Snapshots[] | {"TagName":(.Tags[0].Key // "None"), "TagValue":(.Tags[0].Value // "None"), "desc":(if (.desc | length) == 0 then "None" else . end), "snap id":.SnapshotId, "size":.VolumeSize, "created":.StartTime, "point":(now-($AGE|tonumber)|todate), "aged":(.StartTime < (now-($AGE|tonumber)|todate))} | select(.aged==true)]')
AWS_SNAP_COUNT=$(jq '[.[] .aged] | length' <<< "$AWS_SNAP_DRAFT")
AWS_SNAP_SIZE=$(jq '[.[] .size] | add' <<< "$AWS_SNAP_DRAFT")
AWS_SNAP_LIST=$(jq -r '["created", "TagValue", "TagName", "desc", "snap id", "size"] as $fields | ["------------------------","--------","-------","----","----------------------","----"], $fields, ["------------------------","--------","-------","----","----------------------","----"], (.[] | [.[$fields[]]]) | @tsv' <<< "$AWS_SNAP_DRAFT" | column -ts$'\t')

if ((AWS_SNAP_COUNT>0)); then
    AWS_SNAP_SUMM=$(jq -n "${AWS_SNAP_SIZE:=0} * $AWS_SNAP_PRICE")
    printf "You have %s aged EBS snapshots (more than %s day since creating), which cost you approximately \$%.2f per month \n" "$AWS_SNAP_COUNT" "$AWS_EBS_SNAP_DAYS" "$AWS_SNAP_SUMM"
    printf "These snapshots are:\n"
    printf "%s\n" "$AWS_SNAP_LIST"
else
    printf "You have no aged EBS snapshots"
fi
printf "\n\n"


#Counting and showing list of orphaned EBS Snapshots.
printf "=== Orphaned EBS Snapshots ===\n"
AWS_EBS_ORF=$(comm -23 <(echo $(aws --region "$AWS_REGION" --profile "$AWS_CLI_PROFILE" ec2 describe-snapshots --owner-ids self --query 'Snapshots[*].[VolumeId]' --output text | sort | uniq) | tr ' ' '\n') <(echo $(aws --region "$AWS_REGION" --profile "$AWS_CLI_PROFILE" ec2 describe-volumes --query 'Volumes[*].[VolumeId]' --output text | sort | uniq) | tr ' ' '\n') | tr '\n' ',' | sed 's/\,$//')
AWS_EBS_ORF_COUNT=$(comm -23 <(echo $(aws --region "$AWS_REGION" --profile "$AWS_CLI_PROFILE" ec2 describe-snapshots --owner-ids self --query 'Snapshots[*].[VolumeId]' --output text | sort | uniq) | tr ' ' '\n') <(echo $(aws --region "$AWS_REGION" --profile "$AWS_CLI_PROFILE" ec2 describe-volumes --query 'Volumes[*].[VolumeId]' --output text | sort | uniq) | tr ' ' '\n') | wc -l)
AWS_EBS_ORF_DRAFT=$(aws --region "$AWS_REGION" --profile "$AWS_CLI_PROFILE" ec2 describe-snapshots --owner-ids self --query 'Snapshots[*].{volid:VolumeId,desc:Description,size:VolumeSize,created:StartTime,id:SnapshotId}' --filters Name=volume-id,Values="$AWS_EBS_ORF")
AWS_EBS_ORF_SIZE=$(jq '[.[] .size] | add' <<< "$AWS_EBS_ORF_DRAFT")
AWS_EBS_ORF_LIST=$(aws --region "$AWS_REGION" --profile "$AWS_CLI_PROFILE" ec2 describe-snapshots --owner-ids self --query 'Snapshots[*].{volid:VolumeId,desc:Description,size:VolumeSize,created:StartTime,id:SnapshotId}' --filters Name=volume-id,Values="$AWS_EBS_ORF" --output table)

if ((AWS_EBS_ORF_COUNT>0)); then
    AWS_SNAP_SUMM=$(jq -n "${AWS_EBS_ORF_SIZE:=0} * $AWS_SNAP_PRICE")
    printf "You have orphaned EBS snapshots, which cost you approximately \$%.2f per month \n" "$AWS_SNAP_SUMM"
    printf "These snapshots are:\n"
    printf "%s\n" "$AWS_EBS_ORF_LIST"
else
    printf "You have no orphaned EBS snapshots"
fi
printf "\n\n"


#Counting and showing list of aged RDS Snapshots.
printf "== Relational Database Service ==\n"
printf "=== Aged RDS DB Snapshots ===\n"
AWS_DB_SNAP_AGE=$(($AWS_DB_SNAP_DAYS * 86400))
AWS_DB_SNAP_DRAFT=$(aws --region "$AWS_REGION" --profile "$AWS_CLI_PROFILE" rds describe-db-snapshots | jq --arg AGE "$AWS_DB_SNAP_AGE" '[.DBSnapshots[] | {"TagName":(.Tags[0].Key // "None"), "TagValue":(.Tags[0].Value // "None"), "instance id":.DBInstanceIdentifier, "snap id":.DBSnapshotIdentifier, "size":.AllocatedStorage, "created":.SnapshotCreateTime, "point":(now-($AGE|tonumber)|todate), "aged":(.SnapshotCreateTime < (now-($AGE|tonumber)|todate))} | select(.aged==true)]')
AWS_DB_SNAP_COUNT=$(jq '[.[] .aged] | length' <<< "$AWS_DB_SNAP_DRAFT")
AWS_DB_SNAP_SIZE=$(jq '[.[] .size] | add' <<< "$AWS_DB_SNAP_DRAFT")
AWS_DB_SNAP_LIST=$(jq -r '["created", "TagValue", "TagName", "instance id", "snap id", "size"] as $fields | ["------------------------","--------","-------","-----------","------------------------------------","----"], $fields, ["------------------------","--------","-------","-----------","------------------------------------","----"], (.[] | [.[$fields[]]]) | @tsv' <<< "$AWS_DB_SNAP_DRAFT" | column -ts$'\t')

if ((AWS_DB_SNAP_COUNT>0)); then
    AWS_DB_SNAP_SUMM=$(jq -n "${AWS_DB_SNAP_SIZE:=0} * $AWS_DB_SNAP_PRICE")
    printf "You have %s aged DB snapshots (more than %s day since creating), which cost you approximately \$%.2f per month \n" "$AWS_DB_SNAP_COUNT" "$AWS_DB_SNAP_DAYS" "$AWS_DB_SNAP_SUMM"
    printf "These snapshots are:\n"
    printf "%s\n" "$AWS_DB_SNAP_LIST"
else
    printf "You have no aged DB snapshots"
fi
printf "\n\n"


printf "== Informal block ==\n"
#Counting and showing list of Orphaned Load Balancers.
printf "=== Orphaned EC2 Load Balancers ===\n"
AWS_LB_COUNT=$(aws --region "$AWS_REGION" --profile "$AWS_CLI_PROFILE" elb describe-load-balancers --query 'LoadBalancerDescriptions[*].{TagName:Tags[0].Key,TagValue:Tags[0].Value,name:LoadBalancerName,orphan:Instances[0]==null}' --output text | grep -c True)

if ((AWS_LB_COUNT>0)); then
    AWS_LB_LIST=$(aws --region "$AWS_REGION" --profile "$AWS_CLI_PROFILE" elb describe-load-balancers --query 'LoadBalancerDescriptions[*].{TagName:Tags[0].Key,TagValue:Tags[0].Value,name:LoadBalancerName,orphan:Instances[0]==null}' --output table | grep -v False)
    printf "You have %s orphaned load balancers \n" "$AWS_LB_COUNT"
    printf "These load balancers are:\n"
    printf "%s\n" "$AWS_LB_LIST"
else
    printf "You have no orphaned load balancers"
fi
printf "\n\n"


#Counting and showing list of expired certificates.
printf "=== Expired certificates ===\n"
AWS_CERT_COUNT=$(aws --region "$AWS_REGION" --profile "$AWS_CLI_PROFILE" acm list-certificates --certificate-statuses EXPIRED --query 'CertificateSummaryList[*]' --output text | wc -l)

if ((AWS_CERT_COUNT>0)); then
    AWS_CERT_LIST=$(aws --region "$AWS_REGION" --profile "$AWS_CLI_PROFILE" acm list-certificates --certificate-statuses EXPIRED --query 'CertificateSummaryList[*]' --output table)
    printf "You have %s expired certificates \n" "$AWS_CERT_COUNT"
    printf "These certificates are:\n"
    printf "%s\n" "$AWS_CERT_LIST"
else
    printf "You have no expired certificates"
fi
printf "\n\n"
