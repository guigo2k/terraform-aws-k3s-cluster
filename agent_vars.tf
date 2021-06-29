variable "agent_cidr_blocks" {
  description = "A list of CIDR blocks to attach to the ELB"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "agent_ec2_subnets" {
  description = "A list of subnet IDs to launch resources in"
  type        = list(string)
}

variable "agent_elb_subnets" {
  description = "A list of subnet IDs to attach to the ELB"
  type        = list(string)
}

variable "agent_access_logs" {
  description = "An access logs block"
  type        = map(string)
  default     = null
}

variable "agent_listener" {
  description = "A list of listener blocks to attach to the ELB"
  type        = list(any)
  default = [{
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }]
}

variable "agent_health_check" {
  description = "A health_check block"
  type        = map(string)
  default = {
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 3
    target              = "TCP:80"
    interval            = 5
  }
}

variable "agent_managed_policy_arns" {
  description = "Set of exclusive IAM managed policy ARNs to attach to the IAM role"
  type        = set(string)
  default     = []
}

variable "agent_policies" {
  description = "A list of IAM policy documents to attach to the IAM role"
  type        = set(string)
  default     = []
}

variable "agent_instance_type" {
  description = "The type of the instance"
  type        = string
  default     = "t3.small"
}

variable "agent_segurity_groups" {
  description = "A list of security group IDs"
  type        = list(string)
  default     = []
}

variable "agent_volume_size" {
  description = "The size of the volume in gigabytes"
  type        = number
  default     = 20
}

variable "agent_volume_type" {
  description = "The volume type. Can be standard, gp2, gp3, io1, io2, sc1 or st1 (Default: gp2)"
  type        = string
  default     = "gp2"
}

variable "agent_min_size" {
  description = "The minimum size of the Auto Scaling Group"
  type        = number
  default     = 3
}

variable "agent_max_size" {
  description = "The maximum size of the Auto Scaling Group"
  type        = number
  default     = 3
}

variable "agent_desired_capacity" {
  description = "The number of Amazon EC2 instances that should be running in the group"
  type        = number
  default     = 3
}

variable "agent_capacity_rebalance" {
  description = "Indicates whether capacity rebalance is enabled"
  type        = bool
  default     = true
}

variable "agent_default_cooldown" {
  description = "The amount of time, in seconds, after a scaling activity completes before another scaling activity can start"
  type        = number
  default     = 60
}

variable "agent_health_check_grace_period" {
  description = "Time (in seconds) after instance comes into service before checking health"
  type        = number
  default     = 180
}

variable "agent_health_check_type" {
  description = "EC2 or ELB. Controls how health checking is done"
  type        = string
  default     = "ELB"
}

variable "agent_termination_policies" {
  description = "A list of policies to decide how the instances in the Auto Scaling Group should be terminated"
  type        = list(string)
  default     = ["OldestInstance"]
}
