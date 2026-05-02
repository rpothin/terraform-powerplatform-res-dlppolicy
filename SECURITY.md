# Security Policy

## Supported Versions

| Version           | Supported |
| ----------------- | --------- |
| Latest release    | ✅         |
| Previous releases | ❌         |

## Reporting a Vulnerability

If you discover a security vulnerability in this module, please report it responsibly.

### How to Report

1. **Do NOT open a public issue** for security vulnerabilities.
2. Email the maintainer directly at the address listed in [MAINTAINERS.md](MAINTAINERS.md), or use [GitHub's private vulnerability reporting](../../security/advisories/new).
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### What to Expect

- **Acknowledgment** within a reasonable time of your report.
- **Assessment and plan** within a reasonable time, depending on severity.
- **Fix or mitigation** as soon as reasonably possible, depending on severity.

### Scope

This security policy covers the **Terraform module code** in this repository.

The following are **out of scope** and should be reported to their respective upstreams:

| Component                                     | Report To                                                                                      |
| --------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `microsoft/power-platform` Terraform provider | [Provider repository](https://github.com/microsoft/terraform-provider-power-platform/security) |
| Terraform CLI                                 | [HashiCorp security](https://www.hashicorp.com/security)                                       |
| Power Platform service                        | [Microsoft Security Response Center](https://msrc.microsoft.com/)                              |

## Security Best Practices

When using this module:

- Never commit credentials or secrets to version control
- Use OIDC authentication for CI/CD pipelines
- Pin provider and module versions
- Review the [security guidance](docs/security-guidance.md) for Power Platform–specific considerations
