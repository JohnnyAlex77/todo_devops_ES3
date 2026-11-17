# ==========================================
# 1. SECURITY GROUP (Criterio 10: Restricción de accesos)
# ==========================================
resource "aws_security_group" "app_sg" {
  name        = "todo-app-sg-es3"
  description = "Security Group restringido para app ES3"

  # Solo HTTP desde cualquier lugar (para la app)
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH restringido SOLO a tu IP (reemplaza con tu IP real)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["TU_IP_PUBLICA/32"]  # <-- CAMBIA ESTO
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "todo-app-sg-es3" }
}

# ==========================================
# 2. IAM ROLE (Criterio 8: Mínimo privilegio)
# ==========================================
resource "aws_iam_role" "ec2_cloudwatch_role" {
  name = "ec2-cloudwatch-role-es3"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# Política gestionada por AWS para enviar logs a CloudWatch
resource "aws_iam_role_policy_attachment" "cloudwatch_attach" {
  role       = aws_iam_role.ec2_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Política para SSM (acceso sin SSH)
resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ec2_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-profile-es3"
  role = aws_iam_role.ec2_cloudwatch_role.name
}

# ==========================================
# 3. EC2 INSTANCE (App)
# ==========================================
resource "aws_instance" "app_server" {
  ami                  = "ami-0c55b159cbfafe1f0" # Amazon Linux 2 us-west-2
  instance_type        = var.instance_type
  security_groups      = [aws_security_group.app_sg.name]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y docker
    systemctl start docker
    systemctl enable docker
    usermod -aG docker ec2-user
    # Instalar CloudWatch Agent (opcional, si usas agente)
  EOF

  tags = { Name = "todo-app-server-es3" }
}

# ==========================================
# 4. SNS TOPIC + SUSCRIPCIÓN (Criterio 2: Notificaciones)
# ==========================================
resource "aws_sns_topic" "alerts" {
  name = "todo-app-alerts-es3"
}

resource "aws_sns_topic_subscription" "email_sub" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ==========================================
# 5. CLOUDWATCH ALARM (Criterio 2)
# ==========================================
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "todo-app-cpu-alta-es3"
  alarm_description   = "CPU de la instancia supera el 70% por 2 periodos"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 70
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = aws_instance.app_server.id
  }
}

# ==========================================
# 6. CLOUDTRAIL (Criterio 3: Trazabilidad)
# ==========================================
resource "aws_s3_bucket" "cloudtrail_bucket" {
  bucket        = "todo-cloudtrail-logs-es3-${random_id.suffix.hex}"
  force_destroy = true
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_cloudtrail" "trail" {
  name                          = "todo-app-trail-es3"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_bucket.id
  include_global_service_events = true
  is_multi_region_trail         = false
  enable_logging                = true
}

# ==========================================
# 7. CLOUDWATCH LOG GROUP (Criterio 1: Logs)
# ==========================================
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/ec2/todo-app-es3"
  retention_in_days = 7
}