FROM sonarqube:community

# Install OIDC auth plugin for Cognito integration
ADD --chmod=644 https://github.com/sonar-auth-oidc/sonar-auth-oidc/releases/download/v3.0.0/sonar-auth-oidc-plugin-3.0.0.jar /opt/sonarqube/extensions/plugins/
