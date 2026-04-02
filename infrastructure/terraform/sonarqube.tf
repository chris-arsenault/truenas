# =============================================================================
# SonarQube Cognito Client (OAuth2 code flow for SonarQube OIDC plugin)
# =============================================================================

resource "aws_cognito_user_pool_client" "sonarqube" {
  name         = "sonarqube"
  user_pool_id = nonsensitive(data.aws_ssm_parameter.cognito_user_pool_id.value)

  generate_secret                      = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  allowed_oauth_flows_user_pool_client = true
  callback_urls                        = ["https://${local.sonarqube_domain}/oauth2/callback/oidc"]
  supported_identity_providers         = ["COGNITO"]

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]
}

# =============================================================================
# SSM Parameters — SonarQube service config
# =============================================================================

resource "aws_ssm_parameter" "sonarqube_cognito_client_id" {
  name  = "${local.ssm_prefix}/cognito-client-id"
  type  = "String"
  value = aws_cognito_user_pool_client.sonarqube.id
}

resource "aws_ssm_parameter" "sonarqube_cognito_client_secret" {
  name  = "${local.ssm_prefix}/cognito-client-secret"
  type  = "SecureString"
  value = aws_cognito_user_pool_client.sonarqube.client_secret
}

resource "random_password" "sonarqube_passcode" {
  length  = 32
  special = false
}

resource "aws_ssm_parameter" "sonarqube_admin_passcode" {
  name  = "${local.ssm_prefix}/admin-passcode"
  type  = "SecureString"
  value = random_password.sonarqube_passcode.result

  lifecycle {
    ignore_changes = [value]
  }
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
  value = aws_cognito_user_pool_client.sonarqube.id
}
