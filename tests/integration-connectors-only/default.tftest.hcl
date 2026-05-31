# Integration tests for connectors_only management_mode — uses real provider, requires OIDC credentials.
#
# This test file is kept separate from tests/integration/ because it requires an additional
# fixture: an existing OnlyEnvironments DLP policy that Terraform does NOT manage.
#
# Prerequisites (in addition to the standard integration test credentials):
#   TF_VAR_existing_policy_id='<an-existing-OnlyEnvironments-policy-id>'
#     Set via INTEGRATION_TEST_EXISTING_POLICY_ID repository variable in CI.
#     The referenced policy must:
#       - Already exist in the tenant
#       - Be of type OnlyEnvironments
#       - Have at least one environment in its membership list
#         (required for the length assertion below to be meaningful)
#
# These tests are plan-only — they do NOT create, modify, or destroy the fixture policy.
# Run these only via 'make test-integration-connectors-only' or the dedicated CI step.

run "connectors_only_reads_live_policy_environments" {
  command = plan

  variables {
    display_name     = "tftest-connectors-only-dlp-policy"
    environment_type = "OnlyEnvironments"
    management_mode  = "connectors_only"
    # existing_policy_id is set via TF_VAR_existing_policy_id environment variable.
    # var.environments is intentionally omitted — connectors_only mode ignores it.
    # Any environments appearing in the plan were read from the live API, not from var.environments.
  }

  assert {
    condition     = powerplatform_data_loss_prevention_policy.this.environment_type == "OnlyEnvironments"
    error_message = "connectors_only mode must produce an OnlyEnvironments plan."
  }

  assert {
    # Verifies that the live environment list was successfully read from the API
    # and threaded through to the resource. The fixture policy must have at least
    # one environment for this assertion to hold; see prerequisites above.
    condition     = length(tolist(powerplatform_data_loss_prevention_policy.this.environments)) > 0
    error_message = "connectors_only mode must populate environments from the live API. Ensure the fixture policy referenced by TF_VAR_existing_policy_id has at least one environment."
  }

  assert {
    # Confirms management_mode setting is accepted and does not affect environment_type.
    condition     = powerplatform_data_loss_prevention_policy.this.default_connectors_classification == "Blocked"
    error_message = "default_connectors_classification must be Blocked (zero-trust invariant) regardless of management_mode."
  }
}
