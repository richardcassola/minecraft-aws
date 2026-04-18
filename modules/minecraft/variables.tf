variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "server_name" {
  description = "Name tag for the server"
  type        = string
}

variable "alert_email" {
  description = "Email para receber alertas de custo"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}
