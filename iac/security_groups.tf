# --- SECURITY GROUPS (sin reglas inline para evitar dependencia circular) ---

resource "aws_security_group" "vpce_sqs_sg" {
  name        = "${var.project_name}-vpce-sqs-sg-${var.environment}"
  description = "sg-vpce-sqs"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group" "upload_lambda_sg" {
  name        = "${var.project_name}-upload-lambda-sg-${var.environment}"
  description = "sg-upload-lambda"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group" "crop_lambda_sg" {
  name        = "${var.project_name}-crop-lambda-sg-${var.environment}"
  description = "sg-crop-lambda"
  vpc_id      = aws_vpc.main.id
}

data "aws_prefix_list" "s3" {
  name = "com.amazonaws.${var.aws_region}.s3"
}

resource "aws_security_group_rule" "upload_to_sqs_vpce" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.upload_lambda_sg.id
  source_security_group_id = aws_security_group.vpce_sqs_sg.id
}

resource "aws_security_group_rule" "upload_to_s3_vpce" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.upload_lambda_sg.id
  prefix_list_ids   = [data.aws_prefix_list.s3.id]
}

resource "aws_security_group_rule" "crop_to_sqs_vpce" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.crop_lambda_sg.id
  source_security_group_id = aws_security_group.vpce_sqs_sg.id
}

resource "aws_security_group_rule" "crop_to_s3_vpce" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.crop_lambda_sg.id
  prefix_list_ids   = [data.aws_prefix_list.s3.id]
}

resource "aws_security_group_rule" "vpce_from_upload" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.vpce_sqs_sg.id
  source_security_group_id = aws_security_group.upload_lambda_sg.id
}

resource "aws_security_group_rule" "vpce_from_crop" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.vpce_sqs_sg.id
  source_security_group_id = aws_security_group.crop_lambda_sg.id
}
