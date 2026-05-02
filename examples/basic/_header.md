# Basic Example

This example demonstrates the minimal configuration required to create a DLP policy.

The policy will:
- Apply to **all environments** in the tenant
- Block all connectors by default (zero-trust baseline)
- Automatically place unblockable connectors in the NonBusiness group
- Block all custom connectors via a wildcard catch-all rule
