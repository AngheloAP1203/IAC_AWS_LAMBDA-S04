resource "aws_sqs_queue" "image_dlq" {
  name                      = "${var.project_name}-${var.environment}-image-dlq"
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "image_queue" {
  name                      = "${var.project_name}-${var.environment}-image-queue"
  visibility_timeout_seconds = 360
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 20

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.image_dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_sqs_queue_policy" "allow_s3_events" {
  queue_url = aws_sqs_queue.image_queue.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.image_queue.arn
      Condition = {
        ArnLike = { "aws:SourceArn" : aws_s3_bucket.images.arn }
      }
    }]
  })
}
