# Release Checklist

Step-by-step instructions for publishing a new release of the module.

## Pre-Release Validation

### Terraform Registry Requirements

- [ ] GitHub repository is **public** (required for the public Terraform Registry)
- [ ] Repository name follows the `terraform-<PROVIDER>-<NAME>` format (e.g. `terraform-powerplatform-<module-name>`)
- [ ] GitHub repository **description** is set — it becomes the module's short description on the registry
- [ ] Repository adheres to the [standard module structure](https://developer.hashicorp.com/terraform/language/modules/develop/structure)

### Code Quality

- [ ] Example `source` values updated from `../../` to the Terraform Registry address (e.g. `rpothin/<module-name>/powerplatform`)
- [ ] Footer links in `_footer.md` files (root, `examples/`, `examples/basic/`, `examples/complete/`) converted from relative paths to absolute GitHub URLs (relative links 404 on the Terraform Registry)
- [ ] All CI checks pass on the `main` branch
- [ ] `terraform fmt -check -recursive` passes
- [ ] `make validate` passes
- [ ] `terraform-docs .` produces no changes to `README.md`
- [ ] Unit tests pass: `make test-unit`
- [ ] Integration tests pass (if credentials available): `make test-integration`
- [ ] Trivy security scan shows no HIGH/CRITICAL findings: `trivy config --config .trivy.yaml .`
- [ ] All example READMEs are up to date

## Version Tagging Convention

This project follows [Semantic Versioning](https://semver.org/):

- **MAJOR** (`v1.0.0` → `v2.0.0`): Breaking changes to module interface (removed/renamed variables, changed output types)
- **MINOR** (`v1.0.0` → `v1.1.0`): New features, new variables/outputs (backward-compatible)
- **PATCH** (`v1.0.0` → `v1.0.1`): Bug fixes, documentation updates (backward-compatible)

### Pre-release Versions

- Use `v0.x.y` for initial development (before first stable release)
- Pre-release identifiers: `v1.0.0-rc.1` for release candidates

## Publishing Steps

1. **Ensure `main` is up to date**

   ```bash
   git checkout main
   git pull origin main
   ```

2. **Verify all checks pass**

   ```bash
   make check-all
   make test-unit
   trivy config --config .trivy.yaml .
   ```

3. **Create and push the version tag**

   ```bash
   git tag -a v0.1.0 -m "Release v0.1.0: Initial module release"
   git push origin v0.1.0
   ```

4. **Verify the GitHub release**
   - Check that the `release.yml` workflow ran successfully
   - Verify the GitHub Release was created with auto-generated release notes
   - Confirm the release notes accurately describe the changes

5. **Register on the Terraform Registry (first publish only)**

   > Skip this step for subsequent releases — the webhook registered during initial publication handles version detection automatically.

   - Go to [registry.terraform.io](https://registry.terraform.io/) and click **"Upload"** in the top navigation
   - Sign in with GitHub (only public repository access is requested)
   - Select the repository from the list of matching `terraform-<PROVIDER>-<NAME>` repos
   - Click **"Publish Module"** — the registry sets up a webhook and the module appears within seconds

6. **Verify the Terraform Registry listing**
   - Confirm the new version appears on the Terraform Registry (usually within a minute via webhook)
   - If the version is missing, open the module page and select **"Resync Module"** from the "Manage Module" dropdown
   - Check that documentation and inputs/outputs render correctly
   - Test installation with the new version:

     ```hcl
     module "example" {
       source  = "rpothin/<module-name>/powerplatform"
       version = "0.1.0"
       # ...
     }
     ```

## Post-Release

- [ ] Announce the release in GitHub Discussions (if applicable)
- [ ] Update any dependent modules to reference the new version
- [ ] Monitor issues for any regression reports
