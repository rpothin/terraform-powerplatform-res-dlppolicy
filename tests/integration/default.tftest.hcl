# Integration tests — uses real provider, requires OIDC credentials.
#
# Prerequisites:
#   POWER_PLATFORM_USE_OIDC=true                   (signals OIDC mode for the Power Platform provider)
#   POWER_PLATFORM_TENANT_ID=<your-tenant-id>
#   POWER_PLATFORM_CLIENT_ID=<your-client-id>
#   TF_VAR_environments='["<your-sandbox-env-id>"]'  must be exported before running
#   (set INTEGRATION_TEST_ENVIRONMENT_ID repository variable for CI)
#
# For the connectors_only run:
#   TF_VAR_existing_policy_id='<an-existing-policy-id>'  must be exported before running
#   The referenced policy must already exist and be of type OnlyEnvironments.
#   (set INTEGRATION_TEST_EXISTING_POLICY_ID repository variable for CI)
#
# These tests target OnlyEnvironments scope to avoid applying policies tenant-wide
# during test runs. Use a dedicated sandbox environment — DO NOT run against production.
#
# Resources are automatically destroyed after test completion.

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

# Plan-only validation for connectors_only mode against a real existing policy.
# This run does NOT create or modify the referenced policy — it only validates
# that the module can read its live environment list and plan without errors.
#
# This test covers the happy-path that cannot be unit-tested due to Terraform's
# restriction on function calls (tolist/toset) inside mock_provider blocks:
# the ListNestedAttribute "policies" in the data source schema requires typed
# collections that HCL literals alone cannot produce in mock context.
#
# Requires TF_VAR_existing_policy_id to be set to an existing OnlyEnvironments policy ID.
# Skip this run in CI environments where the variable is not available.
# If this plan succeeds (preconditions pass), the data source found the policy
# and its live environment list was successfully read.
run "connectors_only_reads_live_policy_environments" {
  command = plan

  variables {
    display_name     = "tftest-connectors-only-dlp-policy"
    environment_type = "OnlyEnvironments"
    management_mode  = "connectors_only"
    # existing_policy_id is set via TF_VAR_existing_policy_id environment variable
  }

  assert {
    condition     = powerplatform_data_loss_prevention_policy.this.environment_type == "OnlyEnvironments"
    error_message = "connectors_only mode must produce an OnlyEnvironments plan."
  }
}
