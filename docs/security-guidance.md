# Security Guidance for Power Platform Terraform Modules

> **For AI agents:** The agent-facing version of this guidance lives in [`.agents/skills/terraform-security/SKILL.md`](../.agents/skills/terraform-security/SKILL.md), which includes additional input validation patterns and a security checklist. When updating security guidance, keep both files in sync.

This document provides security considerations and patterns for working with Power Platform Terraform modules.

## Credential Handling

### Never Hardcode Credentials

Credentials must never appear in `.tf` files, `.tfvars` files committed to version control, or in state file outputs.

**❌ Don't do this:**

```hcl
provider "powerplatform" {
  client_id     = "12345678-1234-1234-1234-123456789012"
  client_secret = "my-secret-value"
  tenant_id     = "12345678-1234-1234-1234-123456789012"
}
```

**✅ Do this instead:**

```hcl
provider "powerplatform" {
  # Credentials provided via environment variables:
  #   POWER_PLATFORM_CLIENT_ID
  #   POWER_PLATFORM_TENANT_ID
  # Authentication handled via OIDC (recommended) or environment variables
}
```

### Sensitive Variables

Mark any variable that could contain sensitive data:

```hcl
variable "api_key" {
  description = "API key for external service integration."
  type        = string
  sensitive   = true
}

output "connection_string" {
  description = "Connection string for the provisioned resource."
  value       = powerplatform_environment.this.connection_string
  sensitive   = true
}
```

## OIDC Authentication Patterns

OpenID Connect (OIDC) is the **recommended authentication method** for CI/CD pipelines. It eliminates the need for stored client secrets.

### GitHub Actions OIDC Setup

```yaml
permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Terraform Apply
        run: terraform apply -auto-approve
        env:
          ARM_USE_OIDC: "true"  # Signals OIDC mode; the Power Platform provider reuses this AzureRM convention
          POWER_PLATFORM_TENANT_ID: ${{ secrets.POWER_PLATFORM_TENANT_ID }}
          POWER_PLATFORM_CLIENT_ID: ${{ secrets.POWER_PLATFORM_CLIENT_ID }}
```

> **Note:** `ARM_USE_OIDC` retains the `ARM_` prefix because the `microsoft/power-platform` provider reuses this AzureRM convention to signal OIDC token exchange. The identity variables use the provider-specific `POWER_PLATFORM_` prefix. The unrelated `ARM_TENANT_ID` / `ARM_CLIENT_ID` variables are only needed if you separately configure an **Azure Storage Account** as a Terraform state backend.

### Azure AD App Registration

1. Create an App Registration in Azure AD
2. Configure federated credentials for your GitHub repository
3. Grant the app registration Power Platform admin roles
4. Store `POWER_PLATFORM_TENANT_ID` and `POWER_PLATFORM_CLIENT_ID` as repository secrets

## Environment Isolation

### Separate Environments for Testing

```hcl
variable "environment_type" {
  description = "The type of Power Platform environment."
  type        = string

  validation {
    condition     = contains(["Sandbox", "Production", "Developer", "Trial"], var.environment_type)
    error_message = "Environment type must be Sandbox, Production, Developer, or Trial."
  }
}
```

### Best Practices

- Use **Sandbox** environments for development and testing
- Use **separate tenants** for CI/CD integration tests when possible
- Never run integration tests against production environments
- Use naming conventions to identify test resources (e.g., `tftest-*` prefix)

## DLP Boundary Awareness

Data Loss Prevention (DLP) policies in Power Platform may affect resource provisioning. When creating modules that interact with connectors or environments:

### Document Connector Dependencies

```hcl
# This module creates a Power Automate flow that uses the following connectors:
# - Microsoft Dataverse (standard)
# - Office 365 Outlook (standard)
#
# Ensure your DLP policy allows these connectors in the target environment.
```

### Validate DLP Compatibility

```hcl
variable "dlp_policy_id" {
  description = "The ID of the DLP policy to validate against. If not provided, DLP validation is skipped."
  type        = string
  default     = null
}
```

## State File Security

Terraform state may contain sensitive information:

- Use **remote state backends** with encryption at rest
- Restrict access to state files to authorized personnel only
- Never commit state files to version control (enforced by `.gitignore`)
- Consider using `sensitive = true` on outputs to prevent display in logs

## Version Pinning for Security

Pin all versions to prevent supply chain attacks:

```hcl
terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    powerplatform = {
      source  = "microsoft/power-platform"
      version = "~> 4.0"  # Pessimistic constraint allows patch updates
    }
  }
}
```

In GitHub Actions, pin action versions to a **full commit SHA** to prevent supply chain attacks via mutable tags. Comment the human-readable version for maintainability:

```yaml
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
- uses: hashicorp/setup-terraform@b9cd54a3c349d3f38e8881555d616ced269862dd # v3.1.2
- uses: aquasecurity/trivy-action@e368e328979b113139d6f9068e03accaed98a518 # v0.34.1
```

> **Why SHA pinning?** Tags are mutable — they can be force-pushed, deleted, or tampered with if a repository is compromised. The March 2026 Trivy incident ([aquasecurity/trivy#10265](https://github.com/aquasecurity/trivy/discussions/10265)) demonstrated this: an attacker deleted all GitHub Releases and release assets for versions 0.27.0–0.69.1. SHA-pinned references are immutable and survive tag deletion or repository restoration.

> **Dependabot compatibility:** Dependabot understands the `@<sha> # v1.2.3` comment pattern and can automatically propose SHA-pinned updates.

## Trivy Configuration

[Trivy](https://github.com/aquasecurity/trivy) is the static security scanner used by `make security-scan`. It performs static analysis of Terraform files for misconfigurations — no deployment or cloud credentials required.

### Template Defaults

The `.trivy.yaml` shipped with this template is intentionally minimal:

```yaml
severity: HIGH,CRITICAL

scan:
  scanners:
    - misconfig

misconfiguration:
  # Ignore specific rules that produce false positives for template placeholder content
  # Add rule IDs here as needed when template placeholders trigger false positives
```

This reflects the fact that the template has **no real resources**, so there are no genuine cloud misconfigurations to catch. The `ignore-ids` list is empty by design.

### Adjusting `.trivy.yaml` in Real Modules

When you build a real module from this template, you **must** review and adjust `.trivy.yaml`:

| Situation | Action |
|---|---|
| Module defines actual resources (e.g., `powerplatform_environment`, Azure storage backend) | Triage all HIGH/CRITICAL findings; resolve genuine issues or suppress false positives with justification |
| A finding is a confirmed false positive for Power Platform context | Add the rule ID to `misconfiguration.ignore-ids` with an explanatory comment |
| Module is a pure data/lookup module | Consider adding `secret` to the scanners list to catch accidental credential exposure in outputs |
| Organization has custom compliance rules | Add custom Rego policies via `--config-policy ./policies/` |

### Suppressing False Positives

If a Trivy rule produces a false positive that cannot be resolved (e.g., a rule targeting AWS resources flagging a Power Platform configuration), suppress it by rule ID:

```yaml
misconfiguration:
  ignore-ids:
    - AVD-AWS-0086  # Not applicable: Power Platform does not use AWS S3
```

Always include a comment explaining why the rule is suppressed. Uncommented suppressions will be rejected in code review.

### Finding Rule IDs

Rule IDs appear in Trivy output:

```
FAIL - main.tf - AVD-AWS-0086 - ...
```

You can also browse the full rule library at [avd.aquasec.com](https://avd.aquasec.com).

## Supply Chain Hardening for CI/CD Tools

### Binary Installation

Never use `curl | sh` to install tools in CI or development environments. Instead:

1. **Pin to a specific version** — avoid `latest` or `main` branch references
2. **Verify checksums** — download the checksum file from the release and validate before extracting
3. **Use package managers** when available — container images and OS packages are typically signed

**❌ Don't do this:**

```bash
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sudo sh -s -- -b /usr/local/bin
```

**✅ Do this instead:**

```bash
TRIVY_VERSION='0.69.3'
curl -sSLo trivy.tar.gz "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz"
curl -sSLo trivy_checksums.txt "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_checksums.txt"
sha256sum -c <(grep "trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz" trivy_checksums.txt)
tar -xzf trivy.tar.gz trivy
sudo mv trivy /usr/local/bin/
```

### GitHub Actions

For third-party actions, apply defense-in-depth:

1. **Pin to commit SHA** — not tags (tags are mutable)
2. **Set explicit `version`** — when the action downloads a tool binary, pin that version too (e.g., `version: 'v0.69.3'` for trivy-action)
3. **Least-privilege permissions** — set `permissions: contents: read` at the workflow level; never grant `write` unless required
4. **Never use `pull_request_target` with untrusted checkout** — this is the "Pwn Request" pattern that led to the Trivy compromise

### VSCode Extensions

The Trivy incident included a malicious artifact pushed to the **Open VSIX marketplace** (an alternative to the official VS Code Marketplace). The official VS Code Marketplace was not affected. When choosing extensions:

- Prefer extensions from the **official VS Code Marketplace**
- Review extension publisher verification status
- Monitor security advisories for extensions you depend on
