resource "aws_security_group" "agent_elb" {
  description = format("%s elb security group", local.agent)
  name        = format("%s-elb", local.agent)
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "ingress" {
    for_each = [80, 443]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = var.agent_cidr_blocks
    }
  }
}

resource "aws_security_group" "agent_ec2" {
  description = format("%s ec2 security group", local.agent)
  name        = format("%s-ec2", local.agent)
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "ingress" {
    for_each = [80, 443]
    content {
      from_port       = ingress.value
      to_port         = ingress.value
      protocol        = "tcp"
      security_groups = [aws_security_group.agent_elb.id]
    }
  }
}

resource "aws_elb" "agent" {
  name            = local.agent
  subnets         = var.agent_elb_subnets
  security_groups = [aws_security_group.agent_elb.id]

  dynamic "listener" {
    for_each = var.agent_listener
    content {
      instance_port      = listener.value.instance_port
      instance_protocol  = listener.value.instance_protocol
      lb_port            = listener.value.lb_port
      lb_protocol        = listener.value.lb_protocol
      ssl_certificate_id = lookup(listener.value, "ssl_certificate_id", null)
    }
  }

  dynamic "access_logs" {
    for_each = var.agent_access_logs != null ? [var.agent_access_logs] : []
    content {
      bucket        = lookup(access_logs.value, "bucket", null)
      bucket_prefix = lookup(access_logs.value, "bucket_prefix", null)
      interval      = lookup(access_logs.value, "interval", null)
      enabled       = lookup(access_logs.value, "enabled", true)
    }
  }

  health_check {
    healthy_threshold   = lookup(var.agent_health_check, "healthy_threshold", null)
    unhealthy_threshold = lookup(var.agent_health_check, "unhealthy_threshold", null)
    target              = lookup(var.agent_health_check, "target", null)
    interval            = lookup(var.agent_health_check, "interval", null)
    timeout             = lookup(var.agent_health_check, "timeout", null)
  }
}

resource "aws_iam_role" "agent" {
  name                = local.agent
  assume_role_policy  = data.aws_iam_policy_document.assume_role.json
  managed_policy_arns = var.agent_managed_policy_arns

  inline_policy {
    name   = local.agent
    policy = data.aws_iam_policy_document.agent.json
  }
}

resource "aws_iam_role_policy" "agent" {
  for_each    = var.agent_policies
  name_prefix = format("%s-", local.agent)
  role        = aws_iam_role.agent.id
  policy      = each.value
}

resource "aws_iam_instance_profile" "agent" {
  name = local.agent
  role = aws_iam_role.agent.name
}

resource "aws_launch_template" "agent" {
  name                    = local.agent
  image_id                = data.aws_ami.flatcar.id
  instance_type           = var.agent_instance_type
  key_name                = aws_key_pair.k3s.id
  user_data               = base64encode(data.ignition_config.k3s[local.agent].rendered)
  disable_api_termination = var.disable_api_termination
  update_default_version  = true
  ebs_optimized           = true

  vpc_security_group_ids = compact(concat(
    [aws_security_group.k3s.id, aws_security_group.agent_ec2.id],
    var.agent_segurity_groups
  ))

  block_device_mappings {
    device_name = data.aws_ami.flatcar.root_device_name

    ebs {
      volume_size           = var.agent_volume_size
      volume_type           = var.agent_volume_type
      delete_on_termination = var.delete_on_termination
    }
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.agent.name
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional"
    http_put_response_hop_limit = 1
  }

  monitoring {
    enabled = var.monitoring_enabled
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = local.agent })
  }
}

resource "aws_autoscaling_group" "agent" {
  name                      = local.agent
  min_size                  = var.agent_min_size
  max_size                  = var.agent_max_size
  desired_capacity          = var.agent_desired_capacity
  capacity_rebalance        = var.agent_capacity_rebalance
  default_cooldown          = var.agent_default_cooldown
  health_check_grace_period = var.agent_health_check_grace_period
  health_check_type         = var.agent_health_check_type
  vpc_zone_identifier       = var.agent_ec2_subnets
  termination_policies      = var.agent_termination_policies
  load_balancers            = [aws_elb.agent.name]

  launch_template {
    id      = aws_launch_template.agent.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
  }

  lifecycle {
    create_before_destroy = true
  }
}
