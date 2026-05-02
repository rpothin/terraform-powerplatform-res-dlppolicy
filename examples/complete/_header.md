# Complete Example

This example demonstrates a full DLP policy configuration exercising all available options.

The policy will:
- Apply to **specific environments** only (`OnlyEnvironments`)
- Classify **SharePoint Online** and **Microsoft Teams** connectors as Business
- Allow a custom internal API (`https://api.contoso.com/*`) as a Business custom connector
- Automatically place all unblockable connectors (not in Business) in the NonBusiness group
- Block all other connectors (zero-trust default)
- Block all remaining custom connectors via a wildcard catch-all rule
