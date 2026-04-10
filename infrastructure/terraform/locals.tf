data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  prefix           = "nas-sonarqube"
  domain_name      = "ahara.io"
  sonarqube_domain = "sonar.services.${local.domain_name}"
  ssm_prefix       = "/ahara/sonarqube"
}
