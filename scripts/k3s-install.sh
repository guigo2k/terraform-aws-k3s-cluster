#!/usr/bin/env bash

set -xe

aws_get_parameter() {
  local name="$1"
  docker run --rm amazon/aws-cli ssm get-parameter \
    --name "$name" \
    --region "$COREOS_EC2_REGION" \
    --query Parameter.Value \
    --with-decryption \
    --output text
}

aws_put_parameter() {
  local name="$1"
  local value="$2"
  docker run --rm amazon/aws-cli ssm put-parameter \
    --name "$name" \
    --value "$value" \
    --region "$COREOS_EC2_REGION" \
    --type "SecureString" \
    --overwrite
}

k3s_cluster_init() {
  curl -sfL https://get.k3s.io | sh -s - server \
    --node-taint CriticalAddonsOnly=true:NoExecute \
    --tls-san "$COREOS_EC2_HOSTNAME" \
    --tls-san "$COREOS_K3S_HOSTNAME" \
    --token "$COREOS_K3S_TOKEN" \
    --cluster-init
}

k3s_server_join() {
  curl -sfL https://get.k3s.io | sh -s - server \
    --node-taint CriticalAddonsOnly=true:NoExecute \
    --server https://$COREOS_K3S_PRIMARY:6443 \
    --tls-san "$COREOS_EC2_HOSTNAME" \
    --tls-san "$COREOS_K3S_HOSTNAME" \
    --token "$COREOS_K3S_TOKEN"
}

k3s_manifests() {
  local directory="/var/lib/rancher/k3s/server/manifests"
  local manifests=(${manifests})
  if [[ -n "$manifests" ]]; then
    for file in $${manifests[@]}; do
      aws_get_parameter $file > $directory/$file.yaml
    done
  fi
}

k3s_kubeconfig() {
  local name="$(echo ${name} | rev | cut -d- -f2- | rev)-kubeconfig"
  local value=`cat /etc/rancher/k3s/k3s.yaml | sed "s|server: .*|server: https://$COREOS_K3S_HOSTNAME:6443|g"`
  aws_put_parameter "$name" "$value"
}

k3s_server_wait() {
  while ! ncat -z "$COREOS_K3S_PRIMARY" 6443; do
    sleep 5
  done
}

k3s_agent_wait() {
  while ! ncat -z "$COREOS_K3S_HOSTNAME" 6443; do
    sleep 5
  done
}

k3s_agent() {
  k3s_agent_wait
  curl -sfL https://get.k3s.io | sh -s - agent \
    --server https://$COREOS_K3S_HOSTNAME:6443 \
    --token "$COREOS_K3S_TOKEN"
}

k3s_server() {
  if [[ "$COREOS_EC2_HOSTNAME" == "$COREOS_K3S_PRIMARY" ]]; then
    k3s_manifests
    k3s_cluster_init
    k3s_kubeconfig
  else
    k3s_server_wait
    k3s_server_join
  fi
}

main() {
  if [[ ${name} =~ server ]]; then
    k3s_server
  else
    k3s_agent
  fi
}

main
