.PHONY: ci lint fmt terraform-fmt-check

ci: lint fmt terraform-fmt-check

lint:
	cd sonarqube/bootstrap && cargo clippy -- -D warnings

fmt:
	cd sonarqube/bootstrap && cargo fmt -- --check

terraform-fmt-check:
	terraform fmt -check -recursive infrastructure/terraform/
