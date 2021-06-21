locals {
  server_name = format("%s-server", var.name)
}

resource "aws_security_group" "k3s_server" {
  description = "k3s k3s_server security group"
  name        = local.server_name
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

resource "aws_iam_role" "k3s_server" {
  name = local.server_name
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
    name = local.server_name
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Resource = "*"
          Action = [
            "ec2:DescribeInstances",
            "ec2:DescribeTags",
            "ssm:GetParameter",
            "ssm:PutParameter",
          ]
        },
      ]
    })
  }
}

resource "aws_iam_instance_profile" "k3s_server" {
  name = local.server_name
  role = aws_iam_role.k3s_server.name
}

resource "aws_launch_template" "k3s_server" {
  name                    = local.server_name
  update_default_version  = true
  disable_api_termination = false
  ebs_optimized           = true
  image_id                = data.aws_ami.flatcar.id
  instance_type           = var.server_instance_type
  key_name                = aws_key_pair.k3s.id
  user_data               = base64encode(data.ignition_config.k3s_config[local.server_name].rendered)
  vpc_security_group_ids  = [aws_security_group.k3s_server.id]

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = 100
      volume_type           = "gp2"
      delete_on_termination = true
    }
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.k3s_server.name
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
      { Name = local.server_name },
      var.tags
    )
  }
}

resource "aws_autoscaling_group" "k3s_server" {
  name                      = local.server_name
  min_size                  = var.server_node_count
  max_size                  = var.server_node_count
  desired_capacity          = var.server_node_count
  capacity_rebalance        = true
  default_cooldown          = 0
  health_check_grace_period = 60
  health_check_type         = "ELB"
  load_balancers            = [aws_elb.k3s_server.name]
  vpc_zone_identifier       = var.public_subnet_ids
  termination_policies      = ["OldestInstance"]

  launch_template {
    id      = aws_launch_template.k3s_server.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_elb" "k3s_server" {
  name            = local.server_name
  subnets         = var.public_subnet_ids
  security_groups = [aws_security_group.k3s_server.id]

  listener {
    instance_port     = 6443
    instance_protocol = "tcp"
    lb_port           = 6443
    lb_protocol       = "tcp"
  }

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 3
    target              = "TCP:6443"
    interval            = 5
  }
}
