variable "name" {
  description = "Name of the K3S cluster"
  type        = string
}

variable "vpc_id" {
  description = "The VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "server_node_count" {
  description = "Number of server nodes"
  type        = number
  default     = 3
}

variable "agent_min_node_count" {
  description = "agents minimum node count"
  type        = number
  default     = 3
}

variable "agent_max_node_count" {
  description = "Number of agent nodes"
  type        = number
  default     = 10
}

variable "server_instance_type" {
  description = "server nodes instance type"
  type        = string
  default     = "t3.small"
}

variable "agent_instance_type" {
  description = "agent nodes instance type"
  type        = string
  default     = "t3.large"
}

variable "certificate_arn" {
  description = "ARN of the agent certificate"
  type        = string
}

variable "ssm_manifests" {
  description = "List of SSM parameter store manifests to deploy"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
