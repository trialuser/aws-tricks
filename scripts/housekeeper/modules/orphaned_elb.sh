#!/bin/bash
#
# Counting and showing list of Orphaned Load Balancers.

counting_orphaned_elb() {
  printf "${BLUE}=== Orphaned EC2 Load Balancers ===${RESET}\n"
  AWS_LB_COUNT=$(aws --region "$AWS_REGION" --profile "$AWS_CLI_PROFILE"         \
                elb describe-load-balancers --query 'LoadBalancerDescriptions[*].{TagName:Tags[0].Key,TagValue:Tags[0].Value,name:LoadBalancerName,orphan:Instances[0]==null}' --output text | grep -c True)
  
  if ((AWS_LB_COUNT>0)); then
    AWS_LB_LIST=$(aws --region "$AWS_REGION" --profile "$AWS_CLI_PROFILE"        \
                elb describe-load-balancers --query 'LoadBalancerDescriptions[*].{TagName:Tags[0].Key,TagValue:Tags[0].Value,name:LoadBalancerName,orphan:Instances[0]==null}' --output table | grep -v False)
    printf "You have %s orphaned load balancers \n" "$AWS_LB_COUNT"
    printf "These load balancers are:\n"
    printf "%s\n" "$AWS_LB_LIST"
  else
    printf "${GREEN}You have no orphaned load balancers${RESET}"
  fi
}
