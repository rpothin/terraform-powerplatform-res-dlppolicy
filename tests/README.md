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
| `integration-connectors-only/` | Real-provider read-only policy lookup tests | OIDC and an existing policy fixture required | `command = plan` |

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

### `connectors_only` Integration Tests

These tests read an existing `OnlyEnvironments` policy and do not apply or
modify it. Set `TF_VAR_existing_policy_id` to the fixture policy ID and provide
the standard Power Platform OIDC environment variables, then run:

```bash
make test-integration-connectors-only
```

The Make target also runs
`bash tests/integration-connectors-only/assert-missing-policy-fails.sh` with a
nonexistent policy ID and verifies the direct plan fails with a 404/not-found
diagnostic. Terraform's native `expect_failures` does not recognize this
provider data-source diagnostic, so the shell assertion is the authoritative
check. GitHub Actions reads the tenant and fixture configuration from repository
secrets and variables.

The CI workflow also has a manual `workflow_dispatch` benchmark job that runs
independently of apply-based integration tests. It runs sequential, plan-only
comparisons of v0.1.4 and the selected branch, fixes both runs to provider 4.2.1,
checks plan parity, and writes only sanitized timing and comparison results to
the workflow summary. If the baseline plan fails, the runner still attempts the
candidate plan as a read-only diagnostic control, but fails the benchmark without
reporting paired timings or parity.

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
