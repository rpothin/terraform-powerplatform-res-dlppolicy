# Basic Example

This example demonstrates the minimal configuration required to create a DLP policy.

The policy will:
- Apply to **all environments** in the tenant (`environment_type = "AllEnvironments"` — requires Global Admin and takes effect tenant-wide immediately)
- Block all connectors by default (zero-trust baseline)
- Automatically place unblockable connectors in the NonBusiness group
- Block all custom connectors via a wildcard catch-all rule

> **Note:** The module defaults to `OnlyEnvironments` (safer). This example explicitly sets
> `AllEnvironments` to demonstrate tenant-wide scope. For scoped policies, use `OnlyEnvironments`
> with a list of target environment IDs.
