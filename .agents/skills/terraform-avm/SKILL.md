---
name: terraform-avm
description: >
  Azure Verified Modules (AVM) alignment guide for Power Platform Terraform modules.
  Use when checking AVM compliance, reviewing module classification, validating
  variable/output requirements against AVM specs, or understanding known deviations.
  Covers TFNFR and TFFR requirement mapping with Power Platform adaptations.
---

# AVM Alignment Guide for Power Platform Terraform Modules

> This guide maps [Azure Verified Modules (AVM) Terraform specifications](https://azure.github.io/Azure-Verified-Modules/specs/terraform/) to Power Platform community modules. Because AVM targets Azure providers (`azurerm`/`azapi`), this repository is **AVM-aligned** — not fully AVM-compliant. Every deviation is documented with rationale.

## Why "Aligned" Not "Compliant"

AVM certification requires Azure providers and the `Azure/` Terraform registry namespace. Power Platform modules use the `microsoft/power-platform` provider and live outside the AVM registry. However, AVM's structural, quality, and testing requirements represent industry best practice — adopting them makes these modules familiar to anyone who works with AVM and raises the quality bar.

**Rule**: Treat AVM as the design contract. When you must deviate, document the reason.

---

## Table of Contents

- [Requirement Mapping](#requirement-mapping)
- [Module Classification](#module-classification)
- [Provider Requirements](#provider-requirements)
- [Code Style Standards](#code-style-standards)
- [Variable Requirements](#variable-requirements)
- [Output Requirements](#output-requirements)
- [Local Values Standards](#local-values-standards)
- [Terraform Configuration Requirements](#terraform-configuration-requirements)
- [Testing Requirements](#testing-requirements)
- [Documentation Requirements](#documentation-requirements)
- [Breaking Changes & Feature Management](#breaking-changes--feature-management)
- [Contribution Standards](#contribution-standards)
- [Power Platform Interface Patterns](#power-platform-interface-patterns)
- [Known Deviations from AVM](#known-deviations-from-avm)
  - [D7: Telemetry](#d7-telemetry)
- [Compliance Checklist](#compliance-checklist)

---

## Requirement Mapping

AVM requirements use severity levels: **MUST**, **SHOULD**, **MAY**. This guide preserves those levels. Where a requirement is adapted for Power Platform, the adapted version is shown alongside the original AVM identifier.

| Status             | Meaning                                                  |
| ------------------ | -------------------------------------------------------- |
| **Adopted**        | Requirement applies as-is                                |
| **Adapted**        | Requirement applies with Power Platform–specific changes |
| **Not applicable** | Requirement is Azure-specific and does not apply         |

---

## Module Classification

**AVM Ref:** General AVM structure | **Status:** Adopted

Power Platform modules follow the AVM naming taxonomy:

| Prefix  | Type            | Description                         |
| ------- | --------------- | ----------------------------------- |
| `res-*` | Resource module | Single Power Platform resource type |
| `ptn-*` | Pattern module  | Multi-resource deployment blueprint |
| `utl-*` | Utility module  | Helpers, data lookups, exports      |

When cross-referencing other modules (**TFFR1** — Adopted):

- Modules **MUST** be referenced using Terraform registry source with a pinned version
- Modules **MUST NOT** use git references (`git::https://...` or `github.com/...`)

---

## Provider Requirements

**AVM Ref:** TFFR3 | **Status:** Adapted

AVM mandates `azurerm` (>= 4.0) and/or `azapi` (>= 2.0). Power Platform modules replace these with:

| Provider        | Source                     | Constraint                  |
| --------------- | -------------------------- | --------------------------- |
| `powerplatform` | `microsoft/power-platform` | `~> 4.0` (or current major) |

**Requirements:**

- **MUST** declare the provider in `required_providers` with `source` and `version`
- **SHOULD** use pessimistic constraint (`~>`) for the provider version
- **MAY** additionally use `azurerm` or `azapi` when a module needs Azure resources (e.g., VNet integration, managed identities)
- When both Power Platform and Azure providers are used, all providers **MUST** appear in `required_providers`

```hcl
terraform {
  required_providers {
    powerplatform = {
      source  = "microsoft/power-platform"
      version = "~> 4.0"
    }
    # Only when Azure resources are also needed
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}
```

---

## Code Style Standards

### Lower snake_casing

**AVM Ref:** TFNFR4 | **Status:** Adopted

**MUST** use `lower_snake_case` for all identifiers. See [Terraform Style Guide](../terraform-style/SKILL.md) for naming examples.

### Resource & Data Source Ordering

**AVM Ref:** TFNFR6 | **Status:** Adopted

- Resources that are depended on **SHOULD** come first
- Resources with dependencies **SHOULD** be defined close to each other

### Count & for_each Usage

**AVM Ref:** TFNFR7 | **Status:** Adopted

- Use `count` for conditional resource creation
- **MUST** use `map(xxx)` or `set(xxx)` as `for_each` collection
- Map keys or set elements **MUST** be static literals

### Resource & Data Block Internal Ordering

**AVM Ref:** TFNFR8 | **Status:** Adopted

Order within resource/data blocks:

1. **Meta-arguments (top):** `provider`, `count`, `for_each`
2. **Arguments (middle, alphabetical):** required then optional arguments, required then optional nested blocks
3. **Meta-arguments (bottom):** `depends_on`, `lifecycle` (sub-order: `create_before_destroy`, `ignore_changes`, `prevent_destroy`)

Separate sections with blank lines.

### Module Block Ordering

**AVM Ref:** TFNFR9 | **Status:** Adopted

1. **Top:** `source`, `version`, `count`, `for_each`
2. **Middle (alphabetical):** required then optional arguments
3. **Bottom:** `depends_on`, `providers`

### Lifecycle ignore_changes Syntax

**AVM Ref:** TFNFR10 | **Status:** Adopted

`ignore_changes` values **MUST NOT** be enclosed in double quotes.

```hcl
# Good
lifecycle {
  ignore_changes = [tags]
}

# Bad
lifecycle {
  ignore_changes = ["tags"]
}
```

### Null Comparison for Conditional Creation

**AVM Ref:** TFNFR11 | **Status:** Adopted

Wrap conditional parameters in `object` type to avoid "known after apply" issues.

### Dynamic Blocks for Optional Nested Objects

**AVM Ref:** TFNFR12 | **Status:** Adopted

Conditional nested blocks **MUST** use the `dynamic` block pattern:

```hcl
dynamic "block_name" {
  for_each = <condition> ? [<item>] : []
  content {
    # ...
  }
}
```

### Default Values with coalesce/try

**AVM Ref:** TFNFR13 | **Status:** Adopted

Prefer `coalesce()` or `try()` over ternary expressions for default values.

### Provider Declarations in Modules

**AVM Ref:** TFNFR27 | **Status:** Adopted

- `provider` blocks **MUST NOT** be declared in modules (except `configuration_aliases`)
- Provider configurations **SHOULD** be passed in by the caller

---

## Variable Requirements

### Not Allowed Variables

**AVM Ref:** TFNFR14 | **Status:** Adopted

**MUST NOT** add variables like `enabled` or `module_depends_on` that toggle the entire module. Feature toggles for specific resources within the module are acceptable.

### Variable Definition Order

**AVM Ref:** TFNFR15 | **Status:** Adopted

Variables **SHOULD** follow this order:

1. All required fields (alphabetical)
2. All optional fields (alphabetical)

### Variable Naming Rules

**AVM Ref:** TFNFR16 | **Status:** Adopted

- Follow HashiCorp naming conventions
- Feature switches **SHOULD** use positive statements: `xxx_enabled` not `xxx_disabled`

### Variable Declarations (TFNFR17–23)

**AVM Ref:** TFNFR17–23 | **Status:** Adopted

Description, type, sensitive, and nullability rules are already defined in [Development Workflow](../terraform-workflow/SKILL.md) and [Terraform Style Guide](../terraform-style/SKILL.md). Apply those files as the authoritative source. Key AVM additions not covered elsewhere:

- `object` types **SHOULD** use HEREDOC format for the description (TFNFR17)
- Use concrete `object({...})` instead of `map(any)` (TFNFR18)
- `object` variables containing sensitive fields: mark the entire variable `sensitive = true` or extract those fields into separate variables (TFNFR19)
- Sensitive inputs **MUST NOT** have a `default` value (TFNFR23)

### Handling Deprecated Variables

**AVM Ref:** TFNFR24 | **Status:** Adopted

- Move deprecated variables to `deprecated_variables.tf`
- Prefix the description with `DEPRECATED`
- Declare the replacement variable's name
- Clean up during major version releases

---

## Output Requirements

### Discrete Output Attributes

**AVM Ref:** TFFR2 | **Status:** Adopted

- **SHOULD NOT** output entire resource objects — the schema can change with API or provider versions
- Output computed attributes as discrete values (anti-corruption layer pattern)
- For `for_each` resources, output a map of computed attributes keyed to the `for_each` key

> Sensitive and description requirements are covered in [Development Workflow](../terraform-workflow/SKILL.md) and [Terraform Style Guide](../terraform-style/SKILL.md).

### Sensitive Data Outputs

**AVM Ref:** TFNFR29 | **Status:** Adopted — covered in [Development Workflow](../terraform-workflow/SKILL.md) and [Terraform Style Guide](../terraform-style/SKILL.md).

### Handling Deprecated Outputs

**AVM Ref:** TFNFR30 | **Status:** Adopted

- Move deprecated outputs to `deprecated_outputs.tf`
- Define new outputs in `outputs.tf`
- Clean up during major version releases

---

## Local Values Standards

### locals.tf Organization

**AVM Ref:** TFNFR31 | **Status:** Adopted

- `locals.tf` **SHOULD** only contain `locals` blocks
- **MAY** place `locals` blocks next to resources for advanced scenarios

### Alphabetical Local Arrangement

**AVM Ref:** TFNFR32 | **Status:** Adopted

Expressions in `locals` blocks **MUST** be arranged alphabetically.

### Precise Local Types

**AVM Ref:** TFNFR33 | **Status:** Adopted

Use precise types (e.g., `number` for numeric values, not `string`).

---

## Terraform Configuration Requirements

### Terraform Version Requirements

**AVM Ref:** TFNFR25 | **Status:** Adopted

`terraform.tf` **MUST** contain only one `terraform` block. The first line of that block **MUST** define `required_version`, and the constraint **MUST** include both a minimum and a maximum major version bound. See [Terraform Style Guide](../terraform-style/SKILL.md) for the pinning format and code examples.

### Providers in required_providers

**AVM Ref:** TFNFR26 | **Status:** Adopted

The `terraform` block **MUST** contain a `required_providers` block. Additional AVM-specific rules not covered in the style guide:

- Providers **SHOULD** be sorted alphabetically
- Only include directly required providers (no transitive provider declarations)
- `source` **MUST** be in `namespace/name` format

See [Terraform Style Guide](../terraform-style/SKILL.md) for `source` and `version` code examples.

---

## Testing Requirements

### Test Tooling

**AVM Ref:** TFNFR5 | **Status:** Adapted

AVM requires Checkov and tflint with the `azurerm` ruleset. This module set deviates because scan targets are Power Platform resources:

- Checkov is replaced by `trivy config` for security scanning
- tflint is used without the `azurerm`-specific ruleset

For the full required toolchain and test patterns, see [Terraform Testing Guide](../terraform-testing/SKILL.md). This deviation is also documented in [D3: Test tooling](#d3-test-tooling).

### Test Provider Configuration

**AVM Ref:** TFNFR36 | **Status:** Not applicable

The `prevent_deletion_if_contains_resources` setting is specific to the `azurerm` provider and does not apply to the Power Platform provider.

---

## Documentation Requirements

### Module Documentation Generation

**AVM Ref:** TFNFR2, SNFR15 | **Status:** Adopted

- Documentation **MUST** be automatically generated via [terraform-docs](https://github.com/terraform-docs/terraform-docs)
- `README.md` **MUST NOT** be manually edited — it is generated from `_header.md`, `_footer.md`, and terraform-docs output
- Use `_header.md` for introductory content and `_footer.md` for additional notes (including AVM deviation documentation)

---

## Breaking Changes & Feature Management

### Using Feature Toggles

**AVM Ref:** TFNFR34 | **Status:** Adopted

New resources added in minor/patch versions **MUST** include a toggle variable defaulting to `false`:

```hcl
variable "create_data_loss_prevention_policy" {
  description = "Whether to create a DLP policy for the environment."
  type        = bool
  default     = false
  nullable    = false
}

resource "powerplatform_data_loss_prevention_policy" "this" {
  count = var.create_data_loss_prevention_policy ? 1 : 0
  # ...
}
```

### Reviewing Potential Breaking Changes

**AVM Ref:** TFNFR35 | **Status:** Adopted

Breaking changes requiring caution:

**Resource blocks:**

1. Adding a new resource without conditional creation
2. Adding arguments with non-default values
3. Adding nested blocks without `dynamic`
4. Renaming resources without `moved` blocks
5. Changing `count` to `for_each` or vice versa

**Variable/Output blocks:**

1. Deleting or renaming variables
2. Changing variable `type`
3. Changing variable `default` values
4. Changing `nullable` to `false`
5. Changing `sensitive` from `false` to `true`
6. Adding variables without a `default`
7. Deleting outputs
8. Changing output `value`
9. Changing output `sensitive` value

---

## Contribution Standards

### Branch Protection

**AVM Ref:** TFNFR3 | **Status:** Adopted

Module owners **MUST** set branch protection on the default branch:

1. Require pull request before merging
2. Require approval of the most recent reviewable push
3. Dismiss stale PR approvals when new commits are pushed
4. Require linear history
5. Prevent force pushes
6. Do not allow deletions
7. Require CODEOWNERS review
8. No bypassing settings allowed
9. Enforce for administrators

---

## Power Platform Interface Patterns

AVM defines canonical interface specifications for cross-cutting concerns (role assignments, managed identities, locks, tags). This section documents the Power Platform equivalents — or explains why certain AVM interfaces do not apply.

### Tags

**AVM Ref:** Interface Specification — tags | **Status:** Not applicable

Most Power Platform resources do **not** support Azure resource tags natively. The `microsoft/power-platform` provider does not expose a `tags` attribute on most resources. Modules:

- **MUST NOT** add a `tags` variable if the underlying resource does not support it
- **SHOULD** document the absence of tagging support in the module's `_header.md`
- **MAY** support tagging via Azure-side resources when a module provisions complementary Azure infrastructure (e.g., a storage account for Dataverse export)

### Role Assignments and Security Roles

**AVM Ref:** Interface Specification — role_assignments | **Status:** Adapted

Power Platform uses its own security model distinct from Azure RBAC:

- **Environment roles** are managed via Dataverse security roles, not Azure role assignments
- The `powerplatform_data_record` resource can be used to assign Dataverse security roles programmatically
- For environment-level admin access, use `powerplatform_environment_settings` or the relevant environment settings resource

When a module provisions security role assignments, expose them as a `role_assignments` variable following the AVM map-of-objects pattern where feasible:

```hcl
variable "role_assignments" {
  description = <<DESCRIPTION
A map of role assignments to create on the Power Platform environment.
- `role_name` - The name of the Dataverse security role to assign.
- `principal_id` - The Entra ID object ID of the user or group to assign.
DESCRIPTION
  type = map(object({
    role_name    = string
    principal_id = string
  }))
  default  = {}
  nullable = false
}
```

### Managed Identities

**AVM Ref:** Interface Specification — managed_identities | **Status:** Not applicable

Power Platform resources do not expose managed identity configuration through the `microsoft/power-platform` provider. Managed identity use in the Power Platform context refers to the **service principal** used to authenticate the provider itself (configured via OIDC — see [D6: Authentication model](#d6-authentication-model)), not to resource-level identity assignment.

### Resource Locks

**AVM Ref:** Interface Specification — lock | **Status:** Not applicable

The `microsoft/power-platform` provider does not support Azure Management Lock resources. Power Platform environments can be protected using:

- **Managed Environments** (`powerplatform_managed_environment`) — which enable governance controls
- **Environment-level settings** that restrict deletion or modification

Modules **MUST NOT** add an Azure Management Lock (`azurerm_management_lock`) dependency solely to implement this interface.

### Private Endpoints / VNet Integration

**AVM Ref:** Interface Specification — private_endpoints | **Status:** Adapted (Managed Environments only)

Private network connectivity for Power Platform is available through **Managed Environments with VNet injection**. This is a premium capability that requires:

1. A Managed Environment (`powerplatform_managed_environment`)
2. A dedicated Azure VNet subnet
3. Enterprise Policy configuration for network isolation

When a module supports VNet injection, expose connectivity configuration as a structured variable:

```hcl
variable "enterprise_policy_id" {
  description = "The resource ID of the Enterprise Policy to associate with the Managed Environment for VNet injection. Leave null to disable private network connectivity."
  type        = string
  default     = null
}
```

---

## Known Deviations from AVM

This section documents where Power Platform modules intentionally deviate from AVM specifications and why.

### D1: Provider scope

**AVM Ref:** TFFR3

AVM requires `azurerm` and/or `azapi`. Power Platform modules use `microsoft/power-platform` as the primary provider. Azure providers are included only when the module provisions Azure resources alongside Power Platform resources (e.g., VNet integration).

### D2: Module registry namespace

**AVM Ref:** TFFR1

AVM requires modules under the `Azure/` namespace in the Terraform registry. Power Platform community modules will use a community namespace once published, and may reference non-AVM modules where no AVM equivalent exists for Power Platform resources.

### D3: Test tooling

**AVM Ref:** TFNFR5

AVM requires Checkov and tflint with `azurerm` ruleset. Power Platform modules substitute `trivy config` for security scanning and use tflint without the `azurerm`-specific ruleset since the scan targets are Power Platform resources.

### D4: Test provider configuration

**AVM Ref:** TFNFR36

The `prevent_deletion_if_contains_resources` setting is specific to `azurerm` and has no equivalent in the Power Platform provider.

### D5: Configuration file naming

**AVM Ref:** General convention

Some AVM examples and the udpp26 reference implementation use `versions.tf` for the Terraform block. This template uses `terraform.tf` — both names are acceptable as long as the convention is consistent within the module.

### D6: Authentication model

**AVM Ref:** General convention

AVM modules assume Azure AD authentication via `azurerm`/`azapi` provider configuration. Power Platform modules use OIDC federated credentials configured specifically for the Power Platform provider, with environment-specific variables (`ARM_USE_OIDC`, `POWER_PLATFORM_TENANT_ID`, `POWER_PLATFORM_CLIENT_ID`). Note: `ARM_USE_OIDC` retains the `ARM_` prefix because the `microsoft/power-platform` provider reuses this AzureRM convention to signal OIDC mode; `ARM_TENANT_ID`/`ARM_CLIENT_ID` are separate AzureRM variables only needed when an Azure Storage Account is used as a Terraform state backend.

### D7: Telemetry

**AVM Ref:** TELEM1

AVM requires a zero-cost `azurerm_resource_group_template_deployment` telemetry beacon in certified Azure modules, which reports module usage back to Microsoft. Power Platform community modules **MUST NOT** implement this beacon because:

1. These modules are not published under the `Azure/` Terraform registry namespace and are therefore not subject to AVM certification requirements
2. Adding an `azurerm` provider dependency solely for telemetry would introduce an unnecessary Azure dependency into modules that may not use Azure resources at all
3. The `microsoft/power-platform` provider has no equivalent telemetry mechanism

If a module is ever proposed for formal AVM incubation under the `Azure/` namespace, the telemetry approach should be revisited with the AVM core team (`@Azure/avm-core-team`).

---

## Compliance Checklist

Use this checklist when developing or reviewing Power Platform Terraform modules:

### Module Structure

- [ ] Module follows `res-*` / `ptn-*` / `utl-*` naming convention
- [ ] Cross-references use Terraform registry sources with pinned versions
- [ ] `.terraform-docs.yml` present (if applicable)
- [ ] Standard file layout: `main.tf`, `variables.tf`, `outputs.tf`, `locals.tf`, `terraform.tf`

### Code Style

- [ ] All names use `lower_snake_case`
- [ ] Resources ordered with dependencies first
- [ ] `for_each` uses `map()` or `set()` with static keys
- [ ] Resource/data/module blocks follow internal ordering convention
- [ ] `ignore_changes` values not quoted
- [ ] Dynamic blocks used for conditional nested objects
- [ ] `coalesce()` or `try()` used for default values
- [ ] No `provider` declarations in module (except aliases)

### Variables

- [ ] No `enabled` or `module_depends_on` variables
- [ ] Variables ordered: required (alphabetical) then optional (alphabetical)
- [ ] All variables have precise `type` (no `any`)
- [ ] All variables have `description`
- [ ] Collections use `nullable = false`
- [ ] No `sensitive = false` declarations
- [ ] No default values for sensitive inputs
- [ ] Optional inputs have defaults representing the most secure, compliant, and governance-aligned configuration available for the attribute
- [ ] Deprecated variables in `deprecated_variables.tf`

### Outputs

- [ ] Outputs use discrete attributes (anti-corruption layer pattern)
- [ ] Sensitive outputs marked `sensitive = true`
- [ ] Deprecated outputs in `deprecated_outputs.tf`

### Terraform Configuration

- [ ] `terraform.tf` has version constraints with upper bound
- [ ] `required_providers` block present with `source` and `version`
- [ ] Provider versions use pessimistic constraint (`~>`)
- [ ] Locals arranged alphabetically

### Testing & Quality

- [ ] Unit tests with `mock_provider "powerplatform"`
- [ ] Integration tests with real provider (OIDC)
- [ ] `terraform fmt` applied
- [ ] Security scan passes (`trivy config`)
- [ ] New resources have feature toggle variables
- [ ] Breaking changes documented

### Documentation

- [ ] `README.md` generated via terraform-docs (not manually edited)
- [ ] `_header.md` and `_footer.md` used for human-written content
- [ ] AVM deviations documented and linked from `_footer.md`

---

## References

- [Azure Verified Modules — Overview](https://azure.github.io/Azure-Verified-Modules/)
- [AVM Terraform Specifications](https://azure.github.io/Azure-Verified-Modules/specs/terraform/)
- [AVM Resource Module Specs](https://azure.github.io/Azure-Verified-Modules/specs/tf/res/)
- [AVM Pattern Module Specs](https://azure.github.io/Azure-Verified-Modules/specs/tf/ptn/)
- [AVM Utility Module Specs](https://azure.github.io/Azure-Verified-Modules/specs/tf/utl/)
- [AVM Interface Specs](https://azure.github.io/Azure-Verified-Modules/specs/tf/interfaces/)
- [HashiCorp AVM Agent Skill](https://github.com/hashicorp/agent-skills/blob/main/terraform/code-generation/skills/azure-verified-modules/SKILL.md)
- [Power Platform Terraform Provider](https://registry.terraform.io/providers/microsoft/power-platform/latest/docs)
- [UDPP26 Reference Implementation](https://github.com/rpothin/udpp26-power-platform-devex-with-terraform)
