variable "aws_region" {
  default = "us-west-2"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "alert_email" {
  description = "Correo para notificaciones SNS"
  type        = string
}

variable "my_ip" {
  description = "IP pública del desarrollador para restringir SSH"
  type        = string
  default     = "0.0.0.0"
}