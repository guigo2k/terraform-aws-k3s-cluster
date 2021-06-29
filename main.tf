terraform {
  required_providers {
    ignition = {
      source  = "community-terraform-providers/ignition"
      version = "<=2.0.0"
    }
  }
}

locals {
  server = format("%s-server", var.name)
  agent  = format("%s-agent", var.name)
}

resource "aws_key_pair" "k3s" {
  key_name   = var.name
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "random_password" "token" {
  length  = 32
  special = false
}

resource "aws_security_group" "k3s" {
  description = format("%s security group", var.name)
  name        = format("%s", var.name)
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    cidr_blocks     = var.ssh_cidr_blocks
    security_groups = var.ssh_segurity_groups
  }
}
