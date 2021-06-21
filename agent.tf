locals {
  agent_name = format("%s-agent", var.name)
}

resource "aws_security_group" "k3s_agent" {
  description = "k3s agent security group"
  name        = local.agent_name
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "k3s_agent" {
  name = local.agent_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  inline_policy {
    name = local.agent_name
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Resource = "*"
          Action = [
            "ec2:AttachVolume",
            "ec2:CreateSnapshot",
            "ec2:CreateTags",
            "ec2:CreateVolume",
            "ec2:DeleteSnapshot",
            "ec2:DeleteTags",
            "ec2:DeleteVolume",
            "ec2:DescribeAvailabilityZones",
            "ec2:DescribeInstances",
            "ec2:DescribeSnapshots",
            "ec2:DescribeTags",
            "ec2:DescribeVolumes",
            "ec2:DescribeVolumesModifications",
            "ec2:DetachVolume",
            "ec2:ModifyVolume",
          ]
        },
      ]
    })
  }
}

resource "aws_iam_instance_profile" "k3s_agent" {
  name = local.agent_name
  role = aws_iam_role.k3s_agent.name
}

resource "aws_launch_template" "k3s_agent" {
  name                    = local.agent_name
  update_default_version  = true
  disable_api_termination = false
  ebs_optimized           = true
  image_id                = data.aws_ami.flatcar.id
  instance_type           = var.agent_instance_type
  key_name                = aws_key_pair.k3s.id
  user_data               = base64encode(data.ignition_config.k3s_config[local.agent_name].rendered)
  vpc_security_group_ids  = [aws_security_group.k3s_agent.id]

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = 100
      volume_type           = "gp2"
      delete_on_termination = true
    }
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.k3s_agent.name
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional"
    http_put_response_hop_limit = 1
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      { Name = local.agent_name },
      var.tags
    )
  }
}

resource "aws_autoscaling_group" "k3s_agent" {
  name                      = local.agent_name
  min_size                  = var.agent_min_node_count
  max_size                  = var.agent_max_node_count
  desired_capacity          = var.agent_min_node_count
  capacity_rebalance        = true
  default_cooldown          = 0
  health_check_grace_period = 60
  health_check_type         = "ELB"
  load_balancers            = [aws_elb.k3s_agent.name]
  vpc_zone_identifier       = var.public_subnet_ids
  termination_policies      = ["OldestInstance"]
  depends_on                = [aws_autoscaling_group.k3s_server]

  launch_template {
    id      = aws_launch_template.k3s_agent.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_elb" "k3s_agent" {
  name            = local.agent_name
  subnets         = var.public_subnet_ids
  security_groups = [aws_security_group.k3s_agent.id]

  listener {
    instance_port      = 80
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = var.certificate_arn
  }

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 3
    target              = "TCP:80"
    interval            = 5
  }
}
