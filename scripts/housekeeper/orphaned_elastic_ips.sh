#!/bin/bash
# 
# Counting and showing list of orphaned Elastic IPs.

checking_orphaned_ips() {
  printf "Checking region ${AWS_REGION}\n"
  printf "${BLUE}=== Orphaned Elastic IPs ===${RESET}\n"
  AWS_EIP_COUNT=$(aws --region "$AWS_REGION" --profile "$AWS_CLI_PROFILE"      \
              ec2 describe-addresses --query                                   \
              'Addresses[*].[PublicIp,InstanceId]' --output text | grep -c None)

  if ((AWS_EIP_COUNT>0)); then
    AWS_EIP_SUMM=$(jq -n "$AWS_EIP_COUNT * $AWS_EIP_PRICE")
    AWS_EIP_LIST=$(aws --region "$AWS_REGION" --profile "$AWS_CLI_PROFILE"     \
                ec2 describe-addresses --query                                 \
                'Addresses[*].{TagName:Tags[0].Key,TagValue:Tags[0].Value,IP:PublicIp,Orphan:InstanceId==null}'  \
                --output table | grep -v False)
    printf "You have %s unused IPs, which cost you approximately \$%.2f per    \
          month \n" "$AWS_EIP_COUNT" "$AWS_EIP_SUMM"
    printf "These IPs are:\n"
    printf "%s\n" "$AWS_EIP_LIST"
  else
    printf "${GREEN}You have no unused IPs${RESET}"
fi
}