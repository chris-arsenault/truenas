# =============================================================================
# SonarQube Cognito Client (OAuth2 code flow for SonarQube OIDC plugin)
# =============================================================================

module "cognito" {
  source        = "git::https://github.com/chris-arsenault/ahara-tf-patterns.git//modules/cognito-app"
  name          = "sonarqube"
  callback_urls = ["https://${local.sonarqube_domain}/oauth2/callback/oidc"]
}

# =============================================================================
# SSM Parameters — SonarQube service config
# =============================================================================

resource "aws_ssm_parameter" "sonarqube_cognito_client_id" {
  name  = "${local.ssm_prefix}/cognito-client-id"
  type  = "String"
  value = module.cognito.client_id
}

resource "aws_ssm_parameter" "sonarqube_cognito_client_secret" {
  name  = "${local.ssm_prefix}/cognito-client-secret"
  type  = "SecureString"
  value = module.cognito.client_secret
}

resource "random_password" "sonarqube_admin_password" {
  length           = 32
  special          = true
  override_special = "!@#$%^&*"
}

resource "aws_ssm_parameter" "sonarqube_admin_password" {
  name      = "${local.ssm_prefix}/admin-password"
  type      = "SecureString"
  value     = random_password.sonarqube_admin_password.result
  overwrite = true
}

resource "random_password" "sonarqube_scanner_password" {
  length           = 32
  special          = true
  override_special = "!@#$%^&*"
}

resource "aws_ssm_parameter" "sonarqube_scanner_password" {
  name      = "${local.ssm_prefix}/scanner-password"
  type      = "SecureString"
  value     = random_password.sonarqube_scanner_password.result
  overwrite = true
}

resource "aws_ssm_parameter" "sonarqube_url" {
  name  = "${local.ssm_prefix}/url"
  type  = "String"
  value = "https://${local.sonarqube_domain}"
}

resource "aws_ssm_parameter" "sonarqube_ci_token" {
  name  = "${local.ssm_prefix}/ci-token"
  type  = "SecureString"
  value = "PLACEHOLDER"

  lifecycle {
    ignore_changes = [value]
  }
}

# Publish client ID for the auth-trigger client-map to discover
resource "aws_ssm_parameter" "sonarqube_auth_client_entry" {
  name  = "/platform/auth-trigger/clients/sonarqube"
  type  = "String"
  value = module.cognito.client_id
}
