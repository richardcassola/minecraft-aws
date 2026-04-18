variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "server_name" {
  description = "Name tag for the server"
  type        = string
  default     = "minecraft-server"
}

variable "alert_email" {
  description = "Email para receber alertas de custo"
  type        = string
}

