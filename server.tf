resource "aws_security_group" "server_elb" {
  description = format("%s elb security group", local.server)
  name        = format("%s-elb", local.server)
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 6443
    to_port         = 6443
    protocol        = "tcp"
    cidr_blocks     = var.server_cidr_blocks
    security_groups = [aws_security_group.agent_ec2.id]
  }
}

resource "aws_security_group" "server_ec2" {
  description = format("%s ec2 security group", local.server)
  name        = format("%s-ec2", local.server)
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 6443
    to_port         = 6443
    protocol        = "tcp"
    security_groups = [aws_security_group.server_elb.id]
  }
}

resource "aws_elb" "server" {
  name            = local.server
  subnets         = var.server_elb_subnets
  security_groups = [aws_security_group.server_elb.id]

  listener {
    instance_port     = 6443
    instance_protocol = "tcp"
    lb_port           = 6443
    lb_protocol       = "tcp"
  }

  dynamic "access_logs" {
    for_each = var.server_access_logs != null ? [var.server_access_logs] : []
    content {
      bucket        = lookup(access_logs.value, "bucket", null)
      bucket_prefix = lookup(access_logs.value, "bucket_prefix", null)
      interval      = lookup(access_logs.value, "interval", null)
      enabled       = lookup(access_logs.value, "enabled", true)
    }
  }

  health_check {
    healthy_threshold   = lookup(var.server_health_check, "healthy_threshold", null)
    unhealthy_threshold = lookup(var.server_health_check, "unhealthy_threshold", null)
    target              = lookup(var.server_health_check, "target", null)
    interval            = lookup(var.server_health_check, "interval", null)
    timeout             = lookup(var.server_health_check, "timeout", null)
  }
}

resource "aws_iam_role" "server" {
  name                = local.server
  assume_role_policy  = data.aws_iam_policy_document.assume_role.json
  managed_policy_arns = var.server_managed_policy_arns

  inline_policy {
    name   = local.server
    policy = data.aws_iam_policy_document.server.json
  }
}

resource "aws_iam_role_policy" "server" {
  for_each    = var.server_policies
  name_prefix = format("%s-", local.server)
  role        = aws_iam_role.server.id
  policy      = each.value
}

resource "aws_iam_instance_profile" "server" {
  name = local.server
  role = aws_iam_role.server.name
}

resource "aws_launch_template" "server" {
  name                    = local.server
  image_id                = data.aws_ami.flatcar.id
  instance_type           = var.server_instance_type
  key_name                = aws_key_pair.k3s.id
  user_data               = base64encode(data.ignition_config.k3s[local.server].rendered)
  disable_api_termination = var.disable_api_termination
  update_default_version  = true
  ebs_optimized           = true

  vpc_security_group_ids = compact(concat(
    [aws_security_group.k3s.id, aws_security_group.server_ec2.id],
    var.server_segurity_groups
  ))

  block_device_mappings {
    device_name = data.aws_ami.flatcar.root_device_name

    ebs {
      volume_size           = var.server_volume_size
      volume_type           = var.server_volume_type
      delete_on_termination = var.delete_on_termination
    }
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.server.name
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
    tags          = merge(var.tags, { Name = local.server })
  }
}

resource "aws_autoscaling_group" "server" {
  name                      = local.server
  min_size                  = var.server_min_size
  max_size                  = var.server_max_size
  desired_capacity          = var.server_desired_capacity
  capacity_rebalance        = var.server_capacity_rebalance
  default_cooldown          = var.server_default_cooldown
  health_check_grace_period = var.server_health_check_grace_period
  health_check_type         = var.server_health_check_type
  vpc_zone_identifier       = var.server_ec2_subnets
  termination_policies      = var.server_termination_policies
  load_balancers            = [aws_elb.server.name]

  launch_template {
    id      = aws_launch_template.server.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
  }

  lifecycle {
    create_before_destroy = true
  }
}
