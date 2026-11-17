# ==========================================
# 1. SECURITY GROUP (nombre único por ejecución)
# ==========================================
resource "aws_security_group" "app_sg" {
  name        = "todo-app-sg-es3-${random_id.suffix.hex}"
  description = "Security Group restringido para app ES3"

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32"]
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
# 2. IAM (Usar LabRole existente)
# ==========================================
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-profile-es3-${random_id.suffix.hex}"
  role = data.aws_iam_role.lab_role.name
}

# ==========================================
# 3. EC2 INSTANCE
# ==========================================
resource "aws_instance" "app_server" {
  ami                  = "ami-0c55b159cbfafe1f0"
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
  EOF

  tags = { Name = "todo-app-server-es3" }
}

# ==========================================
# 4. SNS + ALARMA
# ==========================================
resource "aws_sns_topic" "alerts" {
  name = "todo-app-alerts-es3-${random_id.suffix.hex}"
}

# COMENTA este recurso si el secret ALERT_EMAIL está vacío
resource "aws_sns_topic_subscription" "email_sub" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "todo-app-cpu-alta-es3-${random_id.suffix.hex}"
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
# 5. CLOUDWATCH LOG GROUP (nombre único)
# ==========================================
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/ec2/todo-app-es3-${random_id.suffix.hex}"
  retention_in_days = 7
}

# ==========================================
# 6. CLOUDTRAIL (con Object Lock deshabilitado)
# ==========================================
resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "cloudtrail_bucket" {
  bucket             = "todo-cloudtrail-logs-es3-${random_id.suffix.hex}"
  force_destroy      = true
  object_lock_enabled = false   # <-- Deshabilita explícitamente Object Lock

  lifecycle {
    ignore_changes = [
      object_lock_configuration
    ]
  }
}

resource "aws_s3_bucket_versioning" "cloudtrail_versioning" {
  bucket = aws_s3_bucket.cloudtrail_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail_public_access_block" {
  bucket                  = aws_s3_bucket.cloudtrail_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudtrail" "trail" {
  name                          = "todo-app-trail-es3-${random_id.suffix.hex}"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_bucket.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true

  depends_on = [
    aws_s3_bucket_versioning.cloudtrail_versioning,
    aws_s3_bucket_public_access_block.cloudtrail_public_access_block
  ]
}