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
- OIDC authentication configured (`ARM_USE_OIDC=true`, `POWER_PLATFORM_TENANT_ID`, `POWER_PLATFORM_CLIENT_ID`)
