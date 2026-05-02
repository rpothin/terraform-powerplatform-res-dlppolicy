# Power Platform Provider Resource Reference

### Resource Taxonomy

| Category | Resource | Description |
|---|---|---|
| **Environments** | `powerplatform_environment` | Core Power Platform environment (sandbox, production, developer, trial) |
| **Environments** | `powerplatform_managed_environment` | Enables Managed Environment premium governance features |
| **Environments** | `powerplatform_environment_settings` | Environment-level configuration settings |
| **Tenant** | `powerplatform_tenant_settings` | Tenant-wide Power Platform settings (single instance per tenant) |
| **Security** | `powerplatform_data_loss_prevention_policy` | DLP connector policy |
| **Solutions** | `powerplatform_solution` | Power Platform solution (container for apps/flows/tables) |
| **Data** | `powerplatform_data_record` | Dataverse record (used for security role assignments, config records) |
| **Connectors** | `powerplatform_connector` | Custom connector definition |
| **Licensing** | `powerplatform_billing_policy` | Environment billing policy (pay-as-you-go linkage) |
| **Settings** | `powerplatform_environment_application_package_install` | Install a Power Platform application |

> **Note:** The provider is actively developed. Always verify available resources and attributes against the [Power Platform provider documentation](https://registry.terraform.io/providers/microsoft/power-platform/latest/docs) before writing code.

### UUID Fields Requiring Validation

These attributes contain GUIDs and should be validated with a regex when accepted as input variables:

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

### Force-Replace vs In-Place Update Behaviour

Some argument changes trigger resource destruction and recreation. Always check the provider docs, but known force-replace arguments include:

| Resource | Argument | Behaviour on Change |
|---|---|---|
| `powerplatform_environment` | `location` | **Force-replace** — changes billing region |
| `powerplatform_environment` | `environment_type` | **Force-replace** for most type transitions |
| `powerplatform_environment` | `dataverse.currency_code` | **Force-replace** |
| `powerplatform_environment` | `dataverse.language_code` | **Force-replace** |
| `powerplatform_solution` | `environment_id` | **Force-replace** — moves to a different environment |
| `powerplatform_managed_environment` | `id` | **Force-replace** — disabling managed env destroys the resource |

**Best practice:** Use `lifecycle { prevent_destroy = true }` on production `powerplatform_environment` resources to guard against accidental deletion.

### Recommended Timeouts

Power Platform operations often have significant propagation delays. Set explicit timeouts to avoid premature failures:

```hcl
resource "powerplatform_environment" "this" {
  # ... arguments ...

  timeouts {
    create = "30m"
    update = "15m"
    delete = "15m"
  }
}

resource "powerplatform_managed_environment" "this" {
  # ... arguments ...

  timeouts {
    create = "10m"
    update = "10m"
    delete = "10m"
  }
}

resource "powerplatform_solution" "this" {
  # ... arguments ...

  timeouts {
    create = "20m"
    delete = "10m"
  }
}
```

### Eventual Consistency Notes

Power Platform is a distributed SaaS platform. Resources may not be immediately queryable after creation:

- **Environments** can take 2–5 minutes to fully provision before child resources can be created in them. Use `depends_on` to ensure ordering.
- **DLP policies** may take 1–2 minutes to propagate tenant-wide.
- **Solutions** installation can take several minutes depending on solution complexity.
- **Tenant settings** changes propagate asynchronously — avoid reading back settings immediately after update in the same apply.

```hcl
# Ensure the environment is fully ready before creating resources within it
resource "powerplatform_solution" "this" {
  environment_id = powerplatform_environment.this.id
  # depends_on is implicit via the reference above, but make it explicit
  # if referencing the environment ID from a data source or variable:
  depends_on = [powerplatform_environment.this]

  timeouts {
    create = "20m"
  }
}
```
