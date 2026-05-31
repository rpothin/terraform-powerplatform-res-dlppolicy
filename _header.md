# Power Platform DLP Policy Module (`res-dlppolicy`)

[![Terraform Registry](https://img.shields.io/badge/Terraform-Registry-blue.svg)](https://registry.terraform.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A **zero-trust, opinionated** Terraform module for managing [Power Platform Data Loss Prevention (DLP) policies](https://learn.microsoft.com/en-us/power-platform/admin/wp-data-loss-prevention) using the [`microsoft/power-platform`](https://registry.terraform.io/providers/microsoft/power-platform/latest) provider.

## Design Principles

This module enforces a zero-trust baseline:

| Concern | Behaviour |
|---|---|
| Default connector group | **Blocked** — all connectors not explicitly classified are blocked |
| Business connectors | Caller-supplied only — pass connector objects via `business_connectors` |
| NonBusiness connectors | **Auto-computed** — all unblockable connectors not in the Business group are placed here automatically |
| Custom connectors | **Blocked** — a wildcard catch-all rule (`*` → Blocked) is always appended last |

## Prerequisites

- Power Platform Terraform provider `~> 4.0`
- A service principal with the **Power Platform Administrator** role
- OIDC authentication configured (`POWER_PLATFORM_USE_OIDC=true`, `POWER_PLATFORM_TENANT_ID`, `POWER_PLATFORM_CLIENT_ID`)

## Environment Scope Management

The `management_mode` variable controls whether Terraform manages both connectors **and** environment membership, or connectors only.

| Mode | Description |
|------|-------------|
| `full` (default) | Terraform is fully authoritative: manages connector classification **and** the policy's environment list. `var.environments` is the source of truth. |
| `connectors_only` | Terraform manages connector classification only. The environment list is read from the live API on every plan/apply and passed back unchanged — effectively a no-op on environments. Suitable when an external process (Power Automate, PPAC) owns environment membership. Only valid for `OnlyEnvironments` policies. Requires `existing_policy_id`. |

### When to use `connectors_only`

**Context A — IaC transition period:** The organization is progressively onboarding existing DLP policies to Terraform while PPAC or Power Automate flows continue to handle environment membership changes. Using `connectors_only` avoids conflicts during this overlap period.

**Context B — Permanent parallel ownership:** The organization uses Terraform for connector governance but has a permanent, separate process (e.g. an environment provisioning flow) that manages which environments belong to which policy. `connectors_only` allows both systems to coexist without interference.

### Onboarding workflow for new `connectors_only` policies

New policies cannot start directly in `connectors_only` mode because the policy must already exist.

1. **Create** the policy with `management_mode = "full"` and at least one environment in `var.environments`:
   ```hcl
   module "dlp_policy" {
     source           = "..."
     display_name     = "My Baseline Policy"
     environment_type = "OnlyEnvironments"
     environments     = ["<initial-env-id>"]
   }
   ```
2. After `terraform apply`, note the `output.resource_id`.
3. **Switch** to `connectors_only` mode — from this point Terraform no longer manages the environment list:
   ```hcl
   module "dlp_policy" {
     source             = "..."
     display_name       = "My Baseline Policy"
     environment_type   = "OnlyEnvironments"
     management_mode    = "connectors_only"
     existing_policy_id = "<resource_id from step 2>"
   }
   ```
4. Hand off (or continue using) the external process for environment membership.

> [!NOTE]
> `var.environments` is silently ignored in `connectors_only` mode. If you provide it, the value has no effect on the applied configuration.

> [!WARNING]
> `connectors_only` is only valid for `OnlyEnvironments` policies. Using it with `AllEnvironments` or `ExceptEnvironments` will fail with a lifecycle precondition error.

