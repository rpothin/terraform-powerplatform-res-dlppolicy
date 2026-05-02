# Nested Modules

This directory is for **nested submodules** — tightly coupled internal components that are not intended to be used independently.

## When to Use Nested Modules

Use this directory for logic that:

- Is an **internal implementation detail** of the parent module
- Should **not** be published separately to the Terraform Registry
- Is **tightly coupled** to the parent module's resources and data flow

## When to Publish a Separate Module

If the functionality:

- Has a **distinct, reusable purpose** beyond this module
- Can be **independently versioned** and consumed
- Serves a broader audience

Then create a new repository from the [module template](https://github.com/rpothin/terraform-powerplatform-module-template) instead.

## Naming Convention

Nested modules should be named descriptively:

```
modules/
├── helper-name/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── README.md
```

Reference from the parent module:

```hcl
module "helper_name" {
  source = "./modules/helper-name"
  # ...
}
```
