terraform {
  required_providers {
    ignition = {
      source  = "community-terraform-providers/ignition"
      version = "<=2.0.0"
    }
  }
}

resource "aws_key_pair" "k3s" {
  key_name   = var.name
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "random_password" "token" {
  length  = 32
  special = false
}

output "k3s_server_lb" {
  value = aws_elb.k3s_server
}
