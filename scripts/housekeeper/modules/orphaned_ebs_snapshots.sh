#!/bin/bash
#
# Counting and showing list of orphaned EBS Snapshots.

counting_orphaned_ebs_snapshots() {
  printf "${BLUE}=== Orphaned EBS Snapshots ===${RESET}\n"
  AWS_EBS_ORF=$(comm -23 <(echo $(aws --region "$AWS_REGION" --profile           \
              "$AWS_CLI_PROFILE" ec2 describe-snapshots --owner-ids self --query \
              'Snapshots[*].[VolumeId]' --output text | sort | uniq) |           \
              tr ' ' '\n') <(echo $(aws --region "$AWS_REGION" --profile         \
              "$AWS_CLI_PROFILE" ec2 describe-volumes --query                    \
              'Volumes[*].[VolumeId]' --output text | sort | uniq) | tr ' ' '\n')\
              | tr '\n' ',' | sed 's/\,$//')
  AWS_EBS_ORF_COUNT=$(comm -23 <(echo $(aws --region "$AWS_REGION" --profile     \
                    "$AWS_CLI_PROFILE" ec2 describe-snapshots --owner-ids self   \
                    --query 'Snapshots[*].[VolumeId]' --output text | sort |     \
                    uniq) | tr ' ' '\n') <(echo $(aws --region "$AWS_REGION"     \
                    --profile "$AWS_CLI_PROFILE" ec2 describe-volumes --query    \
                    'Volumes[*].[VolumeId]' --output text | sort | uniq) |       \
                    tr ' ' '\n') | wc -l)
  AWS_EBS_ORF_DRAFT=$(aws --region "$AWS_REGION" --profile "$AWS_CLI_PROFILE"    \
                  ec2 describe-snapshots --owner-ids self --query                \
                  'Snapshots[*].{volid:VolumeId,desc:Description,size:VolumeSize,created:StartTime,id:SnapshotId}' --filters Name=volume-id,Values="$AWS_EBS_ORF")
  AWS_EBS_ORF_SIZE=$(jq '[.[] .size] | add' <<< "$AWS_EBS_ORF_DRAFT")
  AWS_EBS_ORF_LIST=$(aws --region "$AWS_REGION" --profile "$AWS_CLI_PROFILE"     \
                  ec2 describe-snapshots --owner-ids self --query                \
                  'Snapshots[*].{volid:VolumeId,desc:Description,size:VolumeSize,created:StartTime,id:SnapshotId}' --filters Name=volume-id,Values="$AWS_EBS_ORF" --output table)
  
  if ((AWS_EBS_ORF_COUNT>0)); then
    AWS_SNAP_SUMM=$(jq -n "${AWS_EBS_ORF_SIZE:=0} * $AWS_SNAP_PRICE")
    printf "You have orphaned EBS snapshots, which cost you approximately        \
    \$%.2f per month \n" "$AWS_SNAP_SUMM"
    printf "These snapshots are:\n"
    printf "%s\n" "$AWS_EBS_ORF_LIST"
  else
    printf "${GREEN}You have no orphaned EBS snapshots${RESET}"
  fi
}