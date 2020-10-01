#!/bin/bash
#
# Counting and showing list of orphaned EBS Volumes.
# Price is based on volume type.

counting_orphaned_ebs_volumes() {
  printf "=== EC2 Elastic Block Store ===\n"
  printf "${BLEU}=== Orphaned EBS Volumes ===${RESET}\n"
  AWS_EBS_COUNT=$(aws --region "$AWS_REGION" --profile "$AWS_CLI_PROFILE"        \
                ec2 describe-volumes --query                                     \
                'Volumes[*].[VolumeId,Attachments[0]==null]' --output text |     \
                grep -c True)
  
  if ((AWS_EBS_COUNT>0)); then
    AWS_EBS_gp2_SIZE=$(aws --region "$AWS_REGION" --profile "$AWS_CLI_PROFILE"   \
                      ec2 describe-volumes --query                               \
                      'Volumes[*].{id:VolumeId,orphan:Attachments[0]==null,type:VolumeType,size:Size}'    \
                      --output text | grep True | grep gp2 | awk '{s+=$3} END    \
                      {print s}')
    AWS_EBS_io1_SIZE=$(aws --region "$AWS_REGION" --profile "$AWS_CLI_PROFILE"   \
                      ec2 describe-volumes --query                               \
                      'Volumes[*].{id:VolumeId,orphan:Attachments[0]==null,type:VolumeType,size:Size}'    \
                      --output text | grep True | grep io1 | awk '{s+=$3} END    \
                      {print s}')
    AWS_EBS_st1_SIZE=$(aws --region "$AWS_REGION" --profile "$AWS_CLI_PROFILE"   \
                      ec2 describe-volumes --query                               \
                      'Volumes[*].{id:VolumeId,orphan:Attachments[0]==null,type:VolumeType,size:Size}'    \
                      --output text | grep True | grep st1 | awk '{s+=$3} END    \
                      {print s}')
    AWS_EBS_sc1_SIZE=$(aws --region "$AWS_REGION" --profile "$AWS_CLI_PROFILE"   \
                      ec2 describe-volumes --query                               \
                      'Volumes[*].{id:VolumeId,orphan:Attachments[0]==null,type:VolumeType,size:Size}'    \
                      --output text | grep True | grep sc1 | awk '{s+=$3} END    \
                      {print s}')
    AWS_EBS_mag_SIZE=$(aws --region "$AWS_REGION" --profile "$AWS_CLI_PROFILE"   \
                      ec2 describe-volumes --query                               \
                      'Volumes[*].{id:VolumeId,orphan:Attachments[0]==null,type:VolumeType,size:Size}'    \
                      --output text | grep True | grep standard | awk '{s+=$3}   \
                      END {print s}')
    AWS_EBS_gp2_SUMM=$(jq -n "${AWS_EBS_gp2_SIZE:=0} * $AWS_EBS_gp2_PRICE")
    AWS_EBS_io1_SUMM=$(jq -n "${AWS_EBS_io1_SIZE:=0} * $AWS_EBS_io1_PRICE")
    AWS_EBS_st1_SUMM=$(jq -n "${AWS_EBS_st1_SIZE:=0} * $AWS_EBS_st1_PRICE")
    AWS_EBS_sc1_SUMM=$(jq -n "${AWS_EBS_sc1_SIZE:=0} * $AWS_EBS_sc1_PRICE")
    AWS_EBS_mag_SUMM=$(jq -n "${AWS_EBS_mag_SIZE:=0} * $AWS_EBS_mag_PRICE")
  
    AWS_EBS_SUMM=$(jq -n "$AWS_EBS_gp2_SUMM + $AWS_EBS_io1_SUMM +                \
                  $AWS_EBS_st1_SUMM + $AWS_EBS_sc1_SUMM + $AWS_EBS_mag_SUMM")
    AWS_EBS_LIST=$(aws --region "$AWS_REGION" --profile "$AWS_CLI_PROFILE"       \
                ec2 describe-volumes --query                                     \
                'Volumes[*].{TagName:Tags[0].Key,TagValue:Tags[0].Value,id:VolumeId,orphan:Attachments[0]==null,type:VolumeType,size:Size}' \--output table | grep -v False)
  
    printf "You have total %s unused volumes, which cost you approximately       \
    \$%.2f per month \n" "$AWS_EBS_COUNT" "$AWS_EBS_SUMM"
    printf "These volumes are:\n"
    printf "%s\n" "$AWS_EBS_LIST"
  else
    printf "${GREEN}You have no unused volumes${RESET}"
  fi
}