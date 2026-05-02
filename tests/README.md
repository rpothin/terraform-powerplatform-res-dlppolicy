# Tests

This directory contains Terraform native tests (`.tftest.hcl`) for the module.

## Prerequisites

- **Terraform >= 1.9** (mock providers require >= 1.7)
- **OIDC credentials** for integration tests (optional)

## Test Organization

| Directory | Type | Credentials | Command |
|-----------|------|-------------|---------|
| `unit/` | Mock provider tests | None required | `command = plan` |
| `integration/` | Real provider tests | OIDC required | `command = apply` |

## Running Tests

### Unit Tests

Unit tests use mock providers and require no credentials:

```bash
terraform init -backend=false
terraform test -test-directory=tests/unit
```

### Integration Tests

Integration tests create real resources and require OIDC authentication:

```bash
export ARM_USE_OIDC=true
export POWER_PLATFORM_TENANT_ID=<your-tenant-id>
export POWER_PLATFORM_CLIENT_ID=<your-client-id>

terraform init -backend=false
terraform test -test-directory=tests/integration
```

### All Tests

```bash
terraform test
```

### Verbose Output

```bash
terraform test -verbose
```

## Writing Tests

See the [Terraform Testing Guide](../.agents/skills/terraform-testing/SKILL.md) for detailed guidance on writing tests, including mock provider patterns and assertion examples.
