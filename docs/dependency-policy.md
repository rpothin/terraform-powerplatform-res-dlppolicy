# Dependency Pinning Policy

This document describes the dependency management strategy for Power Platform Terraform modules.

## Philosophy

We follow a **conservative pinning strategy** that balances security (predictable builds) with maintainability (automated updates via Dependabot).

## Version Constraint Strategy

### Terraform Version

```hcl
required_version = ">= 1.9, < 2.0"
```

- **Lower bound**: Minimum version required for features used (mock providers, test improvements)
- **Upper bound**: Prevents automatic adoption of major version changes that may contain breaking changes

### Provider Versions

```hcl
required_providers {
  powerplatform = {
    source  = "microsoft/power-platform"
    version = "~> 4.0"
  }
}
```

- **Pessimistic constraint (`~>`)**: Allows patch and minor updates within the major version
- Prevents breaking changes from major version bumps
- Dependabot proposes updates; maintainers review and merge

### GitHub Actions

Actions are pinned to **full commit SHAs** in workflow files, with human-readable version comments for maintainability:

```yaml
- uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
- uses: hashicorp/setup-terraform@5e8dbf3c6d9deaf4193ca7a8fb23f2ac83bb6c85 # v4.0.0
```

Dependabot monitors for updates and can automatically propose new SHA-pinned references.

## Dependabot Configuration

The [`dependabot.yml`](../.github/dependabot.yml) file configures automated dependency updates:

| Ecosystem        | Directory | Schedule | Purpose                             |
| ---------------- | --------- | -------- | ----------------------------------- |
| `devcontainers`  | `/`       | Weekly   | Dev container feature updates       |
| `github-actions` | `/`       | Weekly   | GitHub Actions version updates      |
| `terraform`      | `/`       | Weekly   | Provider and module version updates |

### Update Cadence

- **Weekly checks**: Dependabot scans for updates every week
- **Automatic PRs**: Updates are proposed as pull requests
- **CI validation**: All PRs run through the full CI pipeline before merge
- **Manual review**: Maintainers review and approve dependency updates

## Upgrade Process

1. Dependabot creates a PR with the version bump
2. CI pipeline runs: format, validate, docs freshness, security scan, unit tests
3. Maintainer reviews the changelog for breaking changes
4. If tests pass and changes are acceptable, merge the PR
5. For major version bumps, create a dedicated branch for testing

## Security Considerations

- Pin GitHub Actions to full commit SHAs (Dependabot ensures freshness)
- Use pessimistic constraints for providers to prevent unexpected breaking changes
- Review Dependabot PRs promptly to stay current with security patches
- Monitor [GitHub Security Advisories](https://github.com/advisories) for Terraform providers
