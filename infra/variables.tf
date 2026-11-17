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

variable "key_name" {
  description = "Nombre del Key Pair para SSH (opcional)"
  default     = ""
}