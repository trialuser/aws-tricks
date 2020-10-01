#!/bin/bash
#
# Counting and showing list of aged RDS Snapshots.

counting_aged_rds_snapshots() {
  printf "== Relational Database Service ==\n"
  printf "${BLUE}=== Aged RDS DB Snapshots ===${RESET}\n"
  AWS_DB_SNAP_AGE=$(($AWS_DB_SNAP_DAYS * 86400))
  AWS_DB_SNAP_DRAFT=$(aws --region "$AWS_REGION" --profile "$AWS_CLI_PROFILE"    \
                    rds describe-db-snapshots | jq --arg AGE "$AWS_DB_SNAP_AGE"  \
                    '[.DBSnapshots[] | {"TagName":(.Tags[0].Key // "None"),"TagValue":(.Tags[0].Value // "None"),"instance id":.DBInstanceIdentifier,"snap id":.DBSnapshotIdentifier,"size":.AllocatedStorage,"created":.SnapshotCreateTime,"point":(now-($AGE|tonumber)|todate),"aged":(.SnapshotCreateTime < (now-($AGE|tonumber)|todate))} | select(.aged==true)]')
  AWS_DB_SNAP_COUNT=$(jq '[.[] .aged] | length' <<< "$AWS_DB_SNAP_DRAFT")
  AWS_DB_SNAP_SIZE=$(jq '[.[] .size] | add' <<< "$AWS_DB_SNAP_DRAFT")
  AWS_DB_SNAP_LIST=$(jq -r '["created", "TagValue", "TagName", "instance id",
                    "snap id", "size"] as $fields |["------------------------","--------","-------","-----------","------------------------------------","----"],$fields,["------------------------","--------","-------","-----------","------------------------------------","----"],(.[] | [.[$fields[]]]) | @tsv' <<< "$AWS_DB_SNAP_DRAFT" |    \
                    column -ts$'\t')
  
  if ((AWS_DB_SNAP_COUNT>0)); then
    AWS_DB_SNAP_SUMM=$(jq -n "${AWS_DB_SNAP_SIZE:=0} * $AWS_DB_SNAP_PRICE")
    printf "You have %s aged DB snapshots (more than %s day since creating),     \
          which cost you approximately \$%.2f per month \n" "$AWS_DB_SNAP_COUNT" \
          "$AWS_DB_SNAP_DAYS" "$AWS_DB_SNAP_SUMM"
    printf "These snapshots are:\n"
    printf "%s\n" "$AWS_DB_SNAP_LIST"
  else
    printf "${GREEN}You have no aged DB snapshots${RESET}"
  fi
}