# Changelog

## [0.2.0] - Unreleased

### Added

- Added optional `bapi_host` and `bapi_scope` variables for sovereign and government cloud policy lookups.

### Changed

- `connectors_only` now reads the target policy with one BAP API GET instead of enumerating every DLP policy in the tenant.
- A missing policy now fails planning with the provider's HTTP 404 instead of being treated as an empty policy match; malformed or incomplete live responses also block planning.
