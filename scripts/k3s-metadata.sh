#!/usr/bin/env bash

set -xe

k3s_primary() {
  docker run --rm amazon/aws-cli ec2 describe-instances \
    --query "sort_by(Reservations[].Instances[], &LaunchTime)[:1].PrivateDnsName" \
    --filters "Name=tag:Name,Values=${name}" "Name=instance-state-code,Values=16" \
    --region "$COREOS_EC2_REGION" \
    --output text
}

k3s_metadata() {
  local key="$1"
  local val="$2"
  echo "$key=$val" >> /run/metadata/coreos
}

k3s_server() {
  docker pull amazon/aws-cli
  k3s_metadata COREOS_K3S_PRIMARY `k3s_primary`
  k3s_metadata COREOS_K3S_HOSTNAME ${hostname}
  k3s_metadata COREOS_K3S_TOKEN ${token}
}

k3s_agent() {
  k3s_metadata COREOS_K3S_HOSTNAME ${hostname}
  k3s_metadata COREOS_K3S_TOKEN ${token}
}

main() {
  if [[ ${name} =~ server ]]; then
    k3s_server
  else
    k3s_agent
  fi
}

main
