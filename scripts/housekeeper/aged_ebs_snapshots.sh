#!/bin/bash
#
# Counting and showing list of aged EBS Snapshots.
# The age translates into seconds (DAYS * 24 * 60 * 60)

counting_aged_ebs_snapshot() {
  printf "${BLUE}=== Aged EBS Snapshots ===${RESET}\n"
  AWS_EBS_SNAP_AGE=$(($AWS_EBS_SNAP_DAYS * 86400))
  AWS_SNAP_DRAFT=$(aws --region "$AWS_REGION" --profile "$AWS_CLI_PROFILE"     \
                  ec2 describe-snapshots --owner-ids self |                    \
                  jq --arg AGE "$AWS_EBS_SNAP_AGE" '[.Snapshots[] | {"TagName":(.Tags[0].Key // "None"),"TagValue":(.Tags[0].Value // "None"),"desc":(if (.desc | length) == 0 then "None" else . end),"snap id":.SnapshotId,"size":.VolumeSize,"created":.StartTime,"point":(now-($AGE|tonumber)|todate),"aged":(.StartTime < (now-($AGE|tonumber)|todate))} | select(.aged==true)]')
  AWS_SNAP_COUNT=$(jq '[.[] .aged] | length' <<< "$AWS_SNAP_DRAFT")
  AWS_SNAP_SIZE=$(jq '[.[] .size] | add' <<< "$AWS_SNAP_DRAFT")
  AWS_SNAP_LIST=$(jq -r '["created", "TagValue", "TagName", "desc", "snap id", "size"] as $fields | ["------------------------","--------","-------","----","----------------------","----"],$fields,["------------------------","--------","-------","----","----------------------","----"],(.[] | [.[$fields[]]]) | @tsv' <<< "$AWS_SNAP_DRAFT" | column -ts$'\t')
  
  if ((AWS_SNAP_COUNT>0)); then
    AWS_SNAP_SUMM=$(jq -n "${AWS_SNAP_SIZE:=0} * $AWS_SNAP_PRICE")1
    printf "You have %s aged EBS snapshots (more than %s day since creating),  \
            which cost you approximately \$%.2f per month \n" "$AWS_SNAP_COUNT"\
            "$AWS_EBS_SNAP_DAYS" "$AWS_SNAP_SUMM"
    printf "These snapshots are:\n"
    printf "%s\n" "$AWS_SNAP_LIST"
  else
    printf "${GREEN}You have no aged EBS snapshots${RESET}"
  fi
}