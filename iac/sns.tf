resource "aws_sns_topic" "dlq_alarm_topic" {
  name = "${var.project_name}-${var.environment}-dlq-alarm-topic"
}
