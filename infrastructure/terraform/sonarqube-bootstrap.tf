# =============================================================================
# SonarQube Bootstrap Lambda
#
# Narrowly scoped Lambda for SonarQube post-deploy tasks:
# - Waits for SonarQube health
# - Creates CI analysis token
# - Stores token in SSM
#
# Runs in VPC to reach SonarQube at 192.168.66.3:30090 via WireGuard VPN.
# =============================================================================

data "aws_ssm_parameter" "private_subnet_ids" {
  name = "/platform/network/private-subnet-ids"
}

data "aws_security_group" "sonar_proxy" {
  filter {
    name   = "tag:sg:role"
    values = ["reverse-proxy"]
  }
  filter {
    name   = "tag:sg:scope"
    values = ["sonar.ahara.io"]
  }
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "archive_file" "sonarqube_bootstrap" {
  type        = "zip"
  source_file = "${path.module}/../../sonarqube/bootstrap/target/lambda/sonarqube-bootstrap/bootstrap"
  output_path = "${path.module}/sonarqube-bootstrap-lambda.zip"
}

resource "aws_iam_role" "sonarqube_bootstrap" {
  name               = "truenas-sonarqube-bootstrap"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "sonarqube_bootstrap_basic" {
  role       = aws_iam_role.sonarqube_bootstrap.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "sonarqube_bootstrap_vpc" {
  role       = aws_iam_role.sonarqube_bootstrap.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "sonarqube_bootstrap_ssm" {
  name = "truenas-sonarqube-bootstrap-ssm"
  role = aws_iam_role.sonarqube_bootstrap.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = ["arn:aws:ssm:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:parameter/platform/sonarqube/admin-password"]
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:PutParameter"]
        Resource = ["arn:aws:ssm:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:parameter/platform/sonarqube/ci-token"]
      }
    ]
  })
}

resource "aws_lambda_function" "sonarqube_bootstrap" {
  function_name = "truenas-sonarqube-bootstrap"
  role          = aws_iam_role.sonarqube_bootstrap.arn
  handler       = "bootstrap"
  runtime       = "provided.al2023"

  filename         = data.archive_file.sonarqube_bootstrap.output_path
  source_code_hash = data.archive_file.sonarqube_bootstrap.output_base64sha256

  timeout     = 660
  memory_size = 128

  vpc_config {
    subnet_ids         = split(",", nonsensitive(data.aws_ssm_parameter.private_subnet_ids.value))
    security_group_ids = [data.aws_security_group.sonar_proxy.id]
  }

  environment {
    variables = {
      SONARQUBE_URL = "http://192.168.66.3:30090"
    }
  }
}

resource "aws_ssm_parameter" "sonarqube_bootstrap_function" {
  name  = "/platform/sonarqube/bootstrap-function-name"
  type  = "String"
  value = aws_lambda_function.sonarqube_bootstrap.function_name
}
