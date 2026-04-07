# =============================================================================
# SonarQube CI Token Lambda
#
# Creates a SonarQube USER_TOKEN for CI analysis and stores it in SSM.
# Waits for SonarQube health, revokes any existing token, generates a new one.
#
# Runs in VPC with VPN access to reach SonarQube at 192.168.66.3:30090.
# =============================================================================

resource "aws_iam_role" "sonarqube_ci_token" {
  name = "${local.prefix}-ci-token"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "sonarqube_ci_token_basic" {
  role       = aws_iam_role.sonarqube_ci_token.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "sonarqube_ci_token_vpc" {
  role       = aws_iam_role.sonarqube_ci_token.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "sonarqube_ci_token_ssm" {
  name = "${local.prefix}-ci-token-ssm"
  role = aws_iam_role.sonarqube_ci_token.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = ["arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/platform/sonarqube/scanner-password"]
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:PutParameter"]
        Resource = ["arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/platform/sonarqube/ci-token"]
      }
    ]
  })
}

module "sonarqube_ci_token" {
  source     = "git::https://github.com/chris-arsenault/ahara-tf-patterns.git//modules/lambda"
  name       = "${local.prefix}-ci-token"
  binary     = "${path.module}/../../backend/target/lambda/sonarqube-ci-token/bootstrap"
  role_arn   = aws_iam_role.sonarqube_ci_token.arn
  timeout    = 660
  vpn_access = true

  environment = {
    SONARQUBE_URL = "http://192.168.66.3:30090"
  }
}

resource "aws_ssm_parameter" "sonarqube_ci_token_function" {
  name  = "/platform/sonarqube/ci-token-function-name"
  type  = "String"
  value = module.sonarqube_ci_token.function_name
}
