---
name: terraform-security
description: >
  Security guidance for Power Platform Terraform modules.
  Use when reviewing security posture, configuring Trivy scanning,
  handling credentials and secrets, setting up OIDC authentication,
  or evaluating DLP policy impacts on module design.
---

# Security Guidance for Power Platform Terraform Modules

> **Human-readable version:** [`docs/security-guidance.md`](../../docs/security-guidance.md) covers the same topics with additional Environment Isolation guidance. When updating security guidance, keep both files in sync.

This skill provides comprehensive security guidance for developing, scanning, and deploying Power Platform Terraform modules. It covers credential handling, authentication, static analysis, input validation, state protection, and DLP considerations.

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

### Sensitive Variables and Outputs

Mark any variable that could contain sensitive data with `sensitive = true`. The same applies to outputs that expose sensitive values.

```hcl
variable "api_key" {
  description = "API key for external service integration."
  type        = string
  sensitive   = true
  # Sensitive inputs MUST NOT have a default value
}

output "connection_string" {
  description = "Connection string for the provisioned resource."
  value       = powerplatform_environment.this.connection_string
  sensitive   = true
}
```

**Rules:**

- Every variable containing secrets or credentials MUST be marked `sensitive = true`
- Every output exposing sensitive data MUST be marked `sensitive = true`
- Sensitive inputs MUST NOT have a `default` value
- Use `nullable = false` when a sensitive variable must always be provided

## OIDC Authentication

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

### Least-Privilege Service Principals

- Grant only the Power Platform roles required by the module
- Use separate app registrations for different environments (dev, staging, prod)
- Review provider permissions periodically and revoke unused access

## Security Scanning with Trivy

[Trivy](https://github.com/aquasecurity/trivy) is the static security scanner used by `make security-scan`. It performs static analysis of Terraform files for misconfigurations — no deployment or cloud credentials required.

### Running a Security Scan

```bash
trivy config .
```

Resolve any **HIGH** or **CRITICAL** findings before committing.

### `.trivy.yaml` Configuration

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

### Adjusting `.trivy.yaml` in Real Modules

When building a real module from this template, review and adjust `.trivy.yaml`:

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

## Input Validation

Use `validation` blocks to reject invalid values early, before Terraform reaches the plan or apply phase.

### UUID Validation Pattern

Many Power Platform resource attributes contain GUIDs. Validate format when accepting as input variables:

| Resource | Attribute | Notes |
|---|---|---|
| `powerplatform_environment` | `id` (computed) | Environment GUID — used as `environment_id` in child resources |
| `powerplatform_environment` | `billing_policy_id` | Optional — links to a billing policy |
| `powerplatform_data_loss_prevention_policy` | `id` (computed) | DLP policy GUID |
| `powerplatform_solution` | `environment_id` | Required — must be a valid environment GUID |
| `powerplatform_data_record` | `environment_id` | Required — must be a valid environment GUID |
| `powerplatform_managed_environment` | `id` (computed) | Same as environment ID for managed environments |

**Validation pattern for UUID inputs:**

```hcl
variable "environment_id" {
  description = "The GUID of the target Power Platform environment."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.environment_id))
    error_message = "environment_id must be a valid lowercase UUID (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)."
  }
}
```

### Version Pinning for Security

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

> **Why SHA pinning?** Tags are mutable — they can be force-pushed, deleted, or tampered with if a repository is compromised. SHA-pinned references are immutable and survive tag deletion or repository restoration.

> **Dependabot compatibility:** Dependabot understands the `@<sha> # v1.2.3` comment pattern and can automatically propose SHA-pinned updates.

## State Security

Terraform state may contain sensitive information. Protect it accordingly.

- Use **remote state backends** with encryption at rest
- Restrict access to state files to authorized personnel only
- Never commit state files to version control (enforced by `.gitignore`)
- Consider using `sensitive = true` on outputs to prevent display in logs
- Exclude secrets from state where possible using `lifecycle { ignore_changes }` for credential fields:

```hcl
resource "example_resource" "this" {
  name     = var.name
  password = var.password

  lifecycle {
    ignore_changes = [password]
  }
}
```

**Never commit:** `.terraform/`, `*.tfstate`, `*.tfplan`

## DLP Policy Considerations

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

DLP policies may restrict connector usage. Always document connector dependencies so consumers understand which DLP policies must allow the connectors the module relies on.

## Supply Chain Hardening

### Binary Installation

Never use `curl | sh` to install tools in CI or development environments. Instead:

1. **Pin to a specific version** — avoid `latest` or `main` branch references
2. **Verify checksums** — download the checksum file from the release and validate before extracting
3. **Use package managers** when available — container images and OS packages are typically signed

### GitHub Actions Hardening

For third-party actions, apply defense-in-depth:

1. **Pin to commit SHA** — not tags (tags are mutable)
2. **Set explicit `version`** — when the action downloads a tool binary, pin that version too
3. **Least-privilege permissions** — set `permissions: contents: read` at the workflow level; never grant `write` unless required
4. **Never use `pull_request_target` with untrusted checkout** — this is the "Pwn Request" pattern

## Security Checklist

Quick reference for security review:

- [ ] No hardcoded credentials in any `.tf` file
- [ ] All sensitive variables marked `sensitive = true`
- [ ] All sensitive outputs marked `sensitive = true`
- [ ] OIDC authentication configured for CI/CD
- [ ] `trivy config .` passes with no HIGH/CRITICAL findings
- [ ] GitHub Actions pinned to full commit SHA
- [ ] No `.terraform/`, `*.tfstate`, or `*.tfplan` committed
- [ ] Provider permissions follow least-privilege

## Related Skills

- **[terraform-workflow](../terraform-workflow/SKILL.md)** — Security scan step in the development workflow (Step 6)
- **[terraform-style](../terraform-style/SKILL.md)** — Security best practices section, variable `sensitive` rules
- **[terraform-testing](../terraform-testing/SKILL.md)** — OIDC credential setup for integration tests
- **[terraform-avm](../terraform-avm/SKILL.md)** — AVM security requirements (sensitive variables, version pinning)
