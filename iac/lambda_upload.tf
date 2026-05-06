# Empaquetado del código
data "archive_file" "upload_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../src/lambdas/upload"
  output_path = "${path.module}/upload_function.zip"
}

resource "aws_lambda_function" "upload" {
  function_name    = "upload-lambda-${var.environment}"
  role             = aws_iam_role.upload_lambda_role.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  memory_size      = 256
  timeout          = 30
  filename         = data.archive_file.upload_zip.output_path
  source_code_hash = data.archive_file.upload_zip.output_base64sha256

  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_group_ids = [aws_security_group.upload_lambda_sg.id]
  }

  environment {
    variables = {
      S3_BUCKET     = aws_s3_bucket.images.id
      UPLOAD_PREFIX = "uploads/"
    }
  }
}

# Permiso para que API Gateway pueda invocar esta Lambda
resource "aws_lambda_permission" "apigw_upload" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.upload.function_name
  principal     = "apigateway.amazonaws.com"
}

resource "aws_cloudwatch_log_group" "upload_logs" {
  name              = "/aws/lambda/upload-lambda-${var.environment}"
  retention_in_days = 14
}
