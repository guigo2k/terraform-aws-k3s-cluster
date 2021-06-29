data "ignition_systemd_unit" "k3s_metadata" {
  name    = "k3s-metadata.service"
  content = <<EOF
[Unit]
Description=k3s metadata service
After=network-online.target coreos-metadata.service docker.service
Wants=network-online.target coreos-metadata.service docker.service
ConditionPathExists=/opt/bin/k3s-metadata.sh
ConditionPathExists=!/opt/bin/k3s

[Service]
Type=oneshot
TimeoutStartSec=180
RemainAfterExit=yes
KillMode=process
EnvironmentFile=/run/metadata/coreos
ExecStart=/usr/bin/bash -c "/opt/bin/k3s-metadata.sh"

[Install]
WantedBy=multi-user.target
EOF
}

data "ignition_systemd_unit" "k3s_install" {
  name    = "k3s-install.service"
  content = <<EOF
[Unit]
Description=k3s install service
After=k3s-metadata.service
Wants=k3s-metadata.service
ConditionPathExists=/opt/bin/k3s-install.sh
ConditionPathExists=!/opt/bin/k3s

[Service]
Type=forking
TimeoutStartSec=300
RemainAfterExit=yes
KillMode=process
EnvironmentFile=/run/metadata/coreos
ExecStart=/usr/bin/bash -c "/opt/bin/k3s-install.sh"

[Install]
WantedBy=multi-user.target
EOF
}

locals {
  k3s_nodes = toset([
    local.agent,
    local.server,
  ])
}

data "ignition_file" "k3s_metadata" {
  for_each   = local.k3s_nodes
  filesystem = "root"
  path       = "/opt/bin/k3s-metadata.sh"
  mode       = 493

  content {
    content = templatefile("${path.module}/scripts/k3s-metadata.sh", {
      name     = each.key
      hostname = aws_elb.server.dns_name
      token    = random_password.token.result
    })
  }
}

data "ignition_file" "k3s_install" {
  for_each   = local.k3s_nodes
  filesystem = "root"
  path       = "/opt/bin/k3s-install.sh"
  mode       = 493

  content {
    content = templatefile("${path.module}/scripts/k3s-install.sh", {
      name      = each.key
      manifests = join(" ", var.ssm_manifests)
    })
  }
}

data "ignition_directory" "k3s_manifests" {
  filesystem = "root"
  path       = "/var/lib/rancher/k3s/server/manifests"
  mode       = 493
}

data "ignition_config" "k3s" {
  for_each = local.k3s_nodes

  directories = [
    data.ignition_directory.k3s_manifests.rendered,
  ]

  files = [
    data.ignition_file.k3s_metadata[each.key].rendered,
    data.ignition_file.k3s_install[each.key].rendered,
  ]

  systemd = [
    data.ignition_systemd_unit.k3s_metadata.rendered,
    data.ignition_systemd_unit.k3s_install.rendered,
  ]
}
