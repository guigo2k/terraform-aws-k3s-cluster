variable "name" {
  description = "Name of the K3S cluster"
  type        = string
}

variable "vpc_id" {
  description = "The VPC ID"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "ssh_cidr_blocks" {
  description = "A list of CIDR blocks to allow"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ssh_segurity_groups" {
  description = "A list of security group IDs to allow"
  type        = list(string)
  default     = []
}

variable "ssm_manifests" {
  description = "List of SSM parameter store manifests to deploy"
  type        = list(string)
  default     = []
}

variable "disable_api_termination" {
  description = "If true, enables EC2 Instance Termination Protection"
  type        = bool
  default     = false
}

variable "delete_on_termination" {
  description = "Whether volumes should be destroyed on instance termination"
  type        = bool
  default     = true
}

variable "monitoring_enabled" {
  description = "If true, the launched EC2 instance will have detailed monitoring enabled"
  type        = bool
  default     = false
}
