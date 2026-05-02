# Importing Pre-Existing Resources

Power Platform tenants always have a **default environment** that cannot be deleted and exists before any Terraform is applied. Modules that manage tenant-wide resources must be able to adopt pre-existing resources using `import` blocks.

## import blocks (Terraform 1.5+)

```hcl
# Adopt the default environment rather than creating a new one
import {
  to = powerplatform_environment.this
  id = "00000000-0000-0000-0000-000000000000"  # Replace with actual environment ID
}
```

## moved blocks — renaming resources without destroying them

```hcl
# Rename a resource without destroying and recreating it
moved {
  from = powerplatform_environment.old_name
  to   = powerplatform_environment.this
}
```

## Best practices for adoption

- Always import into a dedicated module run before making changes
- Use `terraform plan` to verify the import produces no unexpected diffs
- Document which resources are expected to be pre-existing in the module's `_header.md`
- For the default environment, consider making the environment ID a required input variable rather than creating a new environment
