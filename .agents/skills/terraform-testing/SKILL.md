---
name: terraform-testing
description: >
  Terraform testing patterns for Power Platform modules.
  Use when writing, reviewing, or debugging .tftest.hcl files,
  configuring mock providers, writing unit or integration tests,
  testing variable validation, or setting up CI test pipelines.
---

# Terraform Testing Guide for Power Platform Modules

> Adapted from the HashiCorp `terraform-test` skill for Power Platform community modules.

## Overview

Terraform native testing uses `.tftest.hcl` files (available since Terraform 1.6, mock providers since 1.7). Tests validate module behavior without external test frameworks.

## Test File Syntax

```hcl
# A test file contains one or more run blocks executed sequentially
run "test_name" {
  command = plan  # or apply (default)

  # Optional: override variables for this run
  variables {
    name = "test-value"
  }

  # Assertions validate expected behavior
  assert {
    condition     = output.resource_id != ""
    error_message = "Resource ID must not be empty."
  }
}
```

## Run Block Reference

| Attribute         | Description                                                        | Default           | Since   |
| ----------------- | ------------------------------------------------------------------ | ----------------- | ------- |
| `command`         | `plan` or `apply`                                                  | `apply`           | 1.6     |
| `variables`       | Override input variables                                           | Module defaults   | 1.6     |
| `module`          | Reference an alternate module (e.g., an example)                   | Root module       | 1.6     |
| `expect_failures` | List of resources/variables expected to fail                       | None              | 1.6     |
| `assert`          | One or more assertion blocks                                       | Required          | 1.6     |
| `providers`       | Override provider configuration                                    | Default providers | 1.6     |
| `plan_options`    | Fine-grained plan control (`mode`, `refresh`, `replace`, `target`) | See block docs    | 1.6     |
| `state_key`       | Unique key that gives this run block its own isolated state file   | Shared state      | **1.9** |
| `parallel`        | Allow this run block to execute concurrently with other run blocks | `false`           | **1.9** |

## Mock Providers

Mock providers simulate provider behavior without real API calls. Essential for unit testing.

```hcl
mock_provider "powerplatform" {
  # Mock data for data sources
  mock_data "powerplatform_environments" {
    defaults = {
      environments = [{
        id           = "00000000-0000-0000-0000-000000000001"
        display_name = "Mock Environment"
        location     = "unitedstates"
      }]
    }
  }

  # Mock resource behavior
  mock_resource "powerplatform_environment" {
    defaults = {
      id           = "00000000-0000-0000-0000-000000000001"
      display_name = "Mock Environment"
      location     = "unitedstates"
    }
  }
}
```

## Test Organization

### Directory Structure

```
tests/
├── unit/
│   └── default.tftest.hcl       # Mock provider tests
└── integration/
    └── default.tftest.hcl       # Real provider tests
```

### Unit Tests (`tests/unit/`)

- Use `mock_provider "powerplatform"`
- Use `command = plan` — no infrastructure created
- Validate: variable validation, output presence, conditional logic, local computations
- No credentials required
- Fast execution — run on every PR

```hcl
mock_provider "powerplatform" {}

run "validates_required_variables" {
  command = plan

  variables {
    name     = "test-module"
    location = "unitedstates"
  }

  assert {
    condition     = var.name == "test-module"
    error_message = "Variable name was not set correctly."
  }
}
```

### Integration Tests (`tests/integration/`)

- Use real `microsoft/power-platform` provider
- Use `command = apply` — creates real resources
- OIDC authentication via environment variables
- Validate: actual resource creation, provider behavior
- Resources destroyed automatically after test completion

```hcl
# Integration tests use real provider — requires OIDC credentials
# Set these environment variables before running:
#   ARM_USE_OIDC=true                              (signals OIDC mode; reused from AzureRM convention by the Power Platform provider)
#   POWER_PLATFORM_TENANT_ID=<your-tenant-id>
#   POWER_PLATFORM_CLIENT_ID=<your-client-id>

run "creates_resource_successfully" {
  command = apply

  variables {
    name     = "tftest-integration"
    location = "unitedstates"
  }

  assert {
    condition     = output.resource_id != ""
    error_message = "Resource should have been created with a valid ID."
  }
}
```

> **OIDC setup details:** See [terraform-security](../terraform-security/SKILL.md) for the full OIDC authentication guide, including Azure AD app registration, federated credentials, and least-privilege configuration.

## Running Tests

```bash
# Run all tests
terraform test

# Run only unit tests
terraform test -filter=tests/unit/

# Run only integration tests (requires credentials)
terraform test -filter=tests/integration/

# Verbose output
terraform test -verbose
```

## Variable Validation Testing

Test that validation rules correctly reject invalid inputs:

```hcl
run "rejects_empty_name" {
  command = plan

  variables {
    name     = ""
    location = "unitedstates"
  }

  expect_failures = [
    var.name,
  ]
}

run "rejects_invalid_location" {
  command = plan

  variables {
    name     = "valid-name"
    location = "invalid-location"
  }

  expect_failures = [
    var.location,
  ]
}
```

## Testing with Examples

Reference an example as the module under test:

```hcl
run "basic_example_applies" {
  command = apply

  module {
    source = "./examples/basic"
  }

  assert {
    condition     = output.resource_id != ""
    error_message = "Basic example should produce a resource ID."
  }
}
```

## CI Integration

### Unit tests (always run)

```yaml
- name: Run unit tests
  run: terraform test -filter=tests/unit/
```

### Integration tests (conditional on secrets)

```yaml
- name: Run integration tests
  if: env.POWER_PLATFORM_TENANT_ID != ''
  run: terraform test -filter=tests/integration/
  env:
    ARM_USE_OIDC: "true"  # Signals OIDC mode; the Power Platform provider reuses this AzureRM convention
    POWER_PLATFORM_TENANT_ID: ${{ secrets.POWER_PLATFORM_TENANT_ID }}
    POWER_PLATFORM_CLIENT_ID: ${{ secrets.POWER_PLATFORM_CLIENT_ID }}
```

## Best Practices

1. **Name tests descriptively** — Use names that explain what is being validated
2. **Test one thing per run block** — Keep assertions focused
3. **Use `command = plan` for unit tests** — Faster, no side effects
4. **Validate edge cases** — Empty strings, null values, boundary conditions
5. **Test validation rules** — Use `expect_failures` to verify rejection of bad inputs
6. **Keep mocks minimal** — Only mock what's needed for the test
7. **Isolate integration tests** — Use unique naming to avoid resource conflicts
8. **Clean up** — Integration tests auto-destroy, but verify in CI logs
9. **Use `state_key` for independent integration runs** — Prevents state collisions when a test file provisions multiple Power Platform environments; combine with `test { parallel = true }` to reduce CI wall-clock time
10. **Prefer `plan_options { mode = "refresh-only" }` for drift detection** — Add a dedicated run block that uses refresh-only mode to assert that live Power Platform environment state matches the Terraform plan without making changes

## Reference Material

For advanced testing features available in Terraform 1.9+:

- **[Advanced Patterns](references/advanced-patterns.md)** — Parallel execution, state isolation with `state_key`, `plan_options` block, and `test` block configuration
