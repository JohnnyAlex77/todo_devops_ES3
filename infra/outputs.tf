output "instance_public_ip" {
  value = aws_instance.app_server.public_ip
}

output "sns_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

output "cloudtrail_name" {
  value = aws_cloudtrail.trail.name
}