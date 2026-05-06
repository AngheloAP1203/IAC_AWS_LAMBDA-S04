# --- CLOUDWATCH: ALARMA SOBRE DLQ ---
resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  alarm_name          = "dlq-messages-alarm-${var.environment}"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  alarm_actions       = [aws_sns_topic.dlq_alarm_topic.arn]

  dimensions = {
    QueueName = aws_sqs_queue.image_dlq.name
  }
}
