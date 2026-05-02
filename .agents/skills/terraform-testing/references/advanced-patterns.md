# Advanced Testing Patterns (Terraform 1.9+)

Terraform 1.9 introduced first-class parallel execution and per-run state isolation. Because this template requires `terraform >= 1.9`, all three features below are available without constraint.

## Top-level `test` Block

The optional `test` block sits at the top of a `.tftest.hcl` file and configures test-wide behaviour. The most useful knob is `parallel`, which enables concurrent execution of every run block in the file.

```hcl
# tests/integration/default.tftest.hcl
test {
  parallel = true  # Enable parallel execution for all run blocks (default: false)
}
```

> **When to set `parallel = true`**: Set it in integration test files where run blocks provision independent Power Platform environments and you want shorter wall-clock time in CI. Leave it at the default (`false`) in unit test files where sequential assertion order matters.

## Per-run `parallel` Attribute

Individual run blocks can also opt into parallel execution independently of the top-level `test` block:

```hcl
run "provision_sandbox" {
  parallel  = true   # This run may execute concurrently with other parallel=true runs
  command   = apply

  variables {
    environment_display_name = "tftest-sandbox"
    environment_type         = "Sandbox"
  }

  assert {
    condition     = output.environment_id != ""
    error_message = "Sandbox environment must have a valid ID."
  }
}

run "validate_tenant_settings" {
  parallel = false  # Must run after sandbox is provisioned (sequential dependency)
  command  = plan

  assert {
    condition     = output.tenant_id != ""
    error_message = "Tenant ID must be present."
  }
}
```

## `plan_options` Block

The `plan_options` block gives fine-grained control over the plan for a given run block:

```hcl
run "refresh_environment_state" {
  command = apply

  plan_options {
    mode    = "refresh-only"                      # "normal" (default) or "refresh-only"
    refresh = true                                # Whether to refresh state before planning (default: true)
    replace = [powerplatform_environment.this]    # Force replacement of specific resources
    target  = [powerplatform_environment.this]    # Scope plan to specific resources
  }

  assert {
    condition     = output.environment_id != ""
    error_message = "Environment ID must still be present after a refresh-only plan."
  }
}
```

| `plan_options` key | Type     | Default    | Description                                                        |
| ------------------ | -------- | ---------- | ------------------------------------------------------------------ |
| `mode`             | `string` | `"normal"` | `"normal"` performs a full plan; `"refresh-only"` only syncs state |
| `refresh`          | `bool`   | `true`     | Whether Terraform refreshes existing state before planning         |
| `replace`          | `list`   | `[]`       | Force replacement of the listed resource addresses                 |
| `target`           | `list`   | `[]`       | Restrict the plan to the listed resource addresses                 |

## State Isolation with `state_key`

By default every run block in a `.tftest.hcl` file shares a **single** state file. `state_key` breaks that coupling: each unique key gets its own state file. Run blocks with different keys are **completely isolated** and can safely be executed in parallel.

### Why this matters for Power Platform

Power Platform environment names must be unique within a tenant. Without `state_key`, two run blocks that both create `powerplatform_environment` resources share state — a failure in one run can leave orphaned state that blocks the other. With separate keys, each run block owns its own environment lifecycle.

```hcl
# tests/integration/multi_environment.tftest.hcl

test {
  parallel = true  # Run both environments concurrently
}

run "provision_sandbox" {
  state_key = "sandbox"   # Isolated state — independent lifecycle
  command   = apply

  variables {
    environment_display_name = "tftest-sandbox"
    environment_type         = "Sandbox"
  }

  assert {
    condition     = output.environment_id != ""
    error_message = "Sandbox environment must have a valid ID."
  }
}

run "provision_developer" {
  state_key = "developer"  # Independent state — runs concurrently with sandbox
  command   = apply

  variables {
    environment_display_name = "tftest-developer"
    environment_type         = "Developer"
  }

  assert {
    condition     = output.environment_id != ""
    error_message = "Developer environment must have a valid ID."
  }
}
```

### `state_key` guidelines

| Scenario                                              | Recommended strategy                                              |
| ----------------------------------------------------- | ----------------------------------------------------------------- |
| Sequential setup → assert → teardown in one file      | Omit `state_key` (shared state preserves resource references)     |
| Multiple independent environments in one file         | One key per environment (e.g. `"sandbox"`, `"developer"`)         |
| Reusing the same environment across multiple files    | Use an identical key string across files to share state           |
| Complete isolation per PR / branch                    | Derive the key from a CI run ID environment variable              |
