# Integration tests — uses real provider, requires OIDC credentials.
#
# Prerequisites:
#   ARM_USE_OIDC=true                              (signals OIDC mode; reused from AzureRM convention by the Power Platform provider)
#   POWER_PLATFORM_TENANT_ID=<your-tenant-id>
#   POWER_PLATFORM_CLIENT_ID=<your-client-id>
#
# These tests create real resources against a Power Platform tenant.
# Resources are automatically destroyed after test completion.

run "creates_tenant_wide_policy" {
  command = apply

  variables {
    display_name     = "tftest-basic-dlp-policy"
    environment_type = "AllEnvironments"
  }

  assert {
    condition     = output.display_name == "tftest-basic-dlp-policy"
    error_message = "Policy display_name should match the input variable."
  }

  assert {
    condition     = output.resource_id != ""
    error_message = "Policy resource_id must be set after creation."
  }
}

run "creates_policy_with_business_connectors" {
  command = apply

  variables {
    display_name     = "tftest-complete-dlp-policy"
    environment_type = "AllEnvironments"
    business_connectors = [
      { id = "/providers/Microsoft.PowerApps/apis/shared_sharepointonline" },
      { id = "/providers/Microsoft.PowerApps/apis/shared_teams" },
    ]
    custom_connectors_patterns = [
      {
        order            = 1
        host_url_pattern = "https://api.contoso.com/*"
        data_group       = "Business"
      }
    ]
  }

  assert {
    condition     = output.display_name == "tftest-complete-dlp-policy"
    error_message = "Policy display_name should match the input variable."
  }

  assert {
    condition     = output.resource_id != ""
    error_message = "Policy resource_id must be set after creation."
  }
}
