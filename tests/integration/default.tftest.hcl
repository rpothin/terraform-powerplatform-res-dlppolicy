# Integration tests — uses real provider, requires OIDC credentials.
#
# Prerequisites:
#   ARM_USE_OIDC=true                              (signals OIDC mode; reused from AzureRM convention by the Power Platform provider)
#   POWER_PLATFORM_TENANT_ID=<your-tenant-id>
#   POWER_PLATFORM_CLIENT_ID=<your-client-id>
#
# These tests create real resources against a Power Platform tenant.
# Resources are automatically destroyed after test completion.

run "creates_resource_with_required_variables" {
  command = apply

  variables {
    name     = "tftest-integration"
    location = "unitedstates"
  }

  assert {
    condition     = output.name == "tftest-integration"
    error_message = "Resource name should match the input variable."
  }
}

run "creates_resource_with_all_variables" {
  command = apply

  variables {
    name     = "tftest-integration-complete"
    location = "unitedstates"
    tags = {
      environment = "integration-test"
      managed_by  = "terraform-test"
    }
  }

  assert {
    condition     = output.name == "tftest-integration-complete"
    error_message = "Resource name should match the input variable."
  }
}
