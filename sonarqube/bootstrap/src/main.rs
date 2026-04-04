use aws_sdk_ssm::Client as SsmClient;
use lambda_runtime::{service_fn, Error, LambdaEvent};
use serde::{Deserialize, Serialize};
use std::env;
use tracing::{error, info};

#[derive(Deserialize)]
struct Request {
    /// Action to perform: "create-ci-token"
    action: String,
}

#[derive(Serialize)]
struct Response {
    success: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    token: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
}

async fn get_ssm_value(ssm: &SsmClient, name: &str) -> Result<String, String> {
    ssm.get_parameter()
        .name(name)
        .with_decryption(true)
        .send()
        .await
        .map_err(|e| format!("Failed to read {name} from SSM: {e}"))?
        .parameter()
        .and_then(|p| p.value().map(|v| v.to_string()))
        .ok_or_else(|| format!("SSM param {name} has no value"))
}

async fn wait_for_healthy(http: &reqwest::Client, base_url: &str) -> Result<(), String> {
    let url = format!("{base_url}/api/system/status");
    for attempt in 1..=40 {
        if let Ok(resp) = http.get(&url).send().await {
            if let Ok(body) = resp.json::<serde_json::Value>().await {
                if body.get("status").and_then(|s| s.as_str()) == Some("UP") {
                    info!(attempt, "SonarQube is healthy");
                    return Ok(());
                }
            }
        }
        if attempt < 40 {
            info!(attempt, "Waiting for SonarQube health...");
            tokio::time::sleep(std::time::Duration::from_secs(15)).await;
        }
    }
    Err("SonarQube did not become healthy within 10 minutes".into())
}

async fn create_ci_token(
    http: &reqwest::Client,
    base_url: &str,
    scanner_password: &str,
) -> Result<String, String> {
    // Revoke existing CI token (ignore errors)
    let revoke_resp = http
        .post(format!("{base_url}/api/user_tokens/revoke"))
        .basic_auth("scanner", Some(scanner_password))
        .form(&[("login", "scanner"), ("name", "ci")])
        .send()
        .await;
    match &revoke_resp {
        Ok(r) => info!(status = %r.status(), "Revoke existing token"),
        Err(e) => info!(error = %e, "Revoke request failed (continuing)"),
    }

    // Generate new token for the scanner user
    let resp = http
        .post(format!("{base_url}/api/user_tokens/generate"))
        .basic_auth("scanner", Some(scanner_password))
        .form(&[("login", "scanner"), ("name", "ci"), ("type", "USER_TOKEN")])
        .send()
        .await
        .map_err(|e| format!("Failed to call token API: {e}"))?;

    let status = resp.status();
    let body: serde_json::Value = resp
        .json()
        .await
        .map_err(|e| format!("Failed to parse token response: {e}"))?;

    info!(
        status = %status,
        token_type = body.get("type").and_then(|t| t.as_str()).unwrap_or("missing"),
        token_name = body.get("name").and_then(|t| t.as_str()).unwrap_or("missing"),
        login = body.get("login").and_then(|t| t.as_str()).unwrap_or("missing"),
        "Token generate response"
    );

    if !status.is_success() {
        return Err(format!("Token API returned {status}: {body}"));
    }

    body.get("token")
        .and_then(|t| t.as_str())
        .map(|t| t.to_string())
        .ok_or_else(|| format!("No token in response: {body}"))
}

async fn handler(event: LambdaEvent<serde_json::Value>) -> Result<serde_json::Value, Error> {
    let (payload, _ctx) = event.into_parts();
    info!(event = %payload, "SonarQube CI token Lambda invoked");

    let request: Request = serde_json::from_value(payload)?;

    match request.action.as_str() {
        "create-ci-token" => {
            let aws_config = aws_config::load_defaults(aws_config::BehaviorVersion::latest()).await;
            let ssm = SsmClient::new(&aws_config);

            let base_url =
                env::var("SONARQUBE_URL").unwrap_or_else(|_| "http://192.168.66.3:30090".into());
            let scanner_password =
                get_ssm_value(&ssm, "/platform/sonarqube/scanner-password").await?;

            let http = reqwest::Client::new();

            wait_for_healthy(&http, &base_url).await?;
            let token = create_ci_token(&http, &base_url, &scanner_password).await?;

            // Write token to SSM
            ssm.put_parameter()
                .name("/platform/sonarqube/ci-token")
                .r#type(aws_sdk_ssm::types::ParameterType::SecureString)
                .value(&token)
                .overwrite(true)
                .send()
                .await
                .map_err(|e| format!("Failed to write ci-token to SSM: {e}"))?;

            info!("CI token created and stored in SSM");

            Ok(serde_json::to_value(Response {
                success: true,
                token: None, // Don't return the token in the response
                error: None,
            })?)
        }
        _ => {
            let msg = format!("Unknown action: {}", request.action);
            error!(error = msg);
            Ok(serde_json::to_value(Response {
                success: false,
                token: None,
                error: Some(msg),
            })?)
        }
    }
}

#[tokio::main]
async fn main() -> Result<(), Error> {
    rustls::crypto::ring::default_provider()
        .install_default()
        .expect("Failed to install rustls crypto provider");

    tracing_subscriber::fmt()
        .json()
        .with_env_filter(
            tracing_subscriber::EnvFilter::from_default_env().add_directive("info".parse()?),
        )
        .without_time()
        .init();

    lambda_runtime::run(service_fn(handler)).await
}
