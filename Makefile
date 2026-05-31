.PHONY: fmt validate init test test-unit test-integration test-integration-connectors-only docs lint security-scan check-all

fmt:
	terraform fmt -recursive

validate: init
	terraform validate

init:
	terraform init -backend=false

test: test-unit test-integration

test-unit: init
	terraform test -test-directory=tests/unit

test-integration: init
	terraform test -test-directory=tests/integration

test-integration-connectors-only: init
	terraform test -test-directory=tests/integration-connectors-only

docs:
	terraform-docs .
	for dir in examples/*/; do terraform-docs "$$dir"; done

lint:
	terraform fmt -check -recursive

security-scan:
	trivy config --config .trivy.yaml .

check-all: fmt validate docs lint security-scan test-unit
