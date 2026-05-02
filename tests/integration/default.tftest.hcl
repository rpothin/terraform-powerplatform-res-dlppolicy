# Integration tests — uses real provider, requires OIDC credentials.
#
# Prerequisites:
#   POWER_PLATFORM_USE_OIDC=true                   (signals OIDC mode for the Power Platform provider)
#   POWER_PLATFORM_TENANT_ID=<your-tenant-id>
#   POWER_PLATFORM_CLIENT_ID=<your-client-id>
#
# These tests target OnlyEnvironments scope to avoid applying policies tenant-wide
# during test runs. Use a dedicated sandbox environment — DO NOT run against production.
# Override `environments` via TF_VAR_environments or a .tfvars file before running.
#
# Resources are automatically destroyed after test completion.

variables {
  # Placeholder environment ID — overridden at CI runtime via TF_VAR_environments,
  # which is set from the INTEGRATION_TEST_ENVIRONMENT_ID repository variable.
  # To run locally, export: TF_VAR_environments='["<your-env-id>"]'
  environments = ["00000000-0000-0000-0000-000000000001"]
}

run "creates_environment_scoped_policy" {
  command = apply

  variables {
    display_name     = "tftest-basic-dlp-policy"
    environment_type = "OnlyEnvironments"
  }

  assert {
    condition     = output.display_name == "tftest-basic-dlp-policy"
    error_message = "Policy display_name should match the input variable."
  }

  assert {
    condition     = output.resource_id != ""
    error_message = "Policy resource_id must be set after creation."
  }

  assert {
    condition     = powerplatform_data_loss_prevention_policy.this.default_connectors_classification == "Blocked"
    error_message = "default_connectors_classification must be 'Blocked' after apply (zero-trust invariant)."
  }
}

run "creates_policy_with_business_connectors" {
  command = apply

  variables {
    display_name     = "tftest-complete-dlp-policy"
    environment_type = "OnlyEnvironments"
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

  assert {
    condition     = powerplatform_data_loss_prevention_policy.this.default_connectors_classification == "Blocked"
    error_message = "default_connectors_classification must be 'Blocked' after apply (zero-trust invariant)."
  }
}
