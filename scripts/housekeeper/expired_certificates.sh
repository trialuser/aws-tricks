#!/bin/bash
#
# Counting and showing list of expired certificates.

showing_list_of_expired_certificate() {
  printf "${BLUE}=== Expired certificates ===${RESET}\n"
  AWS_CERT_COUNT=$(aws --region "$AWS_REGION" --profile "$AWS_CLI_PROFILE"       \
                  acm list-certificates --certificate-statuses EXPIRED --query   \
                  'CertificateSummaryList[*]' --output text | wc -l)
  
  if ((AWS_CERT_COUNT>0)); then
    AWS_CERT_LIST=$(aws --region "$AWS_REGION" --profile "$AWS_CLI_PROFILE"      \
                  acm list-certificates --certificate-statuses EXPIRED --query   \
                  'CertificateSummaryList[*]' --output table)
    printf "You have %s expired certificates \n" "$AWS_CERT_COUNT"
    printf "These certificates are:\n"
    printf "%s\n" "$AWS_CERT_LIST"
  else
    printf "${GREEN}You have no expired certificates${RESET}"
  fi
}
