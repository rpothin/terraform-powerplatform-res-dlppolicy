data "powerplatform_connectors" "all" {
  environment_id = local._connector_catalog_environment_id
}

# Reads only the target policy's live environment membership.
# The provider returns a diagnostic for non-2xx responses when only 200 is expected.
data "powerplatform_rest_query" "live_policy" {
  count = var.management_mode == "connectors_only" && var.existing_policy_id != null ? 1 : 0

  method               = "GET"
  scope                = var.bapi_scope
  url                  = "https://${var.bapi_host}/providers/PowerPlatform.Governance/v2/policies/${lower(var.existing_policy_id)}"
  expected_http_status = [200]
}

resource "powerplatform_data_loss_prevention_policy" "this" {
  display_name                      = var.display_name
  default_connectors_classification = var.default_connectors_classification
  environment_type                  = var.environment_type
  environments                      = sort(local.effective_environments)

  business_connectors     = var.business_connectors
  non_business_connectors = local.non_business_connectors
  blocked_connectors      = local.blocked_connectors

  custom_connectors_patterns = local.custom_connectors_patterns_with_default_block

  lifecycle {
    precondition {
      condition     = var.management_mode == "connectors_only" || var.environment_type == "AllEnvironments" || length(var.environments) > 0
      error_message = "environments must contain at least one environment ID when environment_type is OnlyEnvironments or ExceptEnvironments."
    }

    precondition {
      condition     = var.management_mode != "connectors_only" || var.environment_type == "OnlyEnvironments"
      error_message = "management_mode 'connectors_only' is only valid for OnlyEnvironments policies. Use management_mode 'full' for ExceptEnvironments and AllEnvironments policies."
    }

    precondition {
      condition     = var.management_mode != "connectors_only" || var.existing_policy_id != null
      error_message = "management_mode 'connectors_only' requires existing_policy_id. The policy must already exist. See the README for the recommended onboarding workflow."
    }

    precondition {
      condition     = var.management_mode != "connectors_only" || var.existing_policy_id == null || (local._live_policy != null && lower(try(local._live_policy.name, "")) == lower(var.existing_policy_id))
      error_message = "management_mode 'connectors_only': the live DLP policy returned by the API does not match existing_policy_id. Verify the ID is correct and the policy exists in the tenant."
    }

    precondition {
      condition     = var.management_mode != "connectors_only" || var.existing_policy_id == null || local._live_policy_environments_valid
      error_message = "management_mode 'connectors_only': the live DLP policy response must contain an environments array with a non-empty name for each environment."
    }
  }
}

# Note: `check` blocks emit advisory warnings only — they do NOT block `terraform apply`.
# If a connector ID is invalid the real failure will come from the provider API at apply time.
# This check provides early feedback during `terraform plan` to surface typos quickly.
check "business_connector_ids_exist" {
  assert {
    condition = length(setsubtract(
      local.business_connector_ids,
      local.all_connector_ids
    )) == 0
    error_message = "One or more business_connectors IDs do not exist in the list of available connectors. Verify the connector IDs are correct and the PowerPlatform provider has access to list connectors."
  }
}

# Advisory: existing_policy_id is only meaningful in connectors_only mode.
# This check warns when the variable is provided in full mode where it has no effect,
# which most likely indicates a misconfiguration or a forgotten cleanup after a mode switch.
check "existing_policy_id_unused_in_full_mode" {
  assert {
    condition     = !(var.management_mode == "full" && var.existing_policy_id != null)
    error_message = "existing_policy_id is set but management_mode is 'full' — the value has no effect. Remove existing_policy_id or switch to management_mode = 'connectors_only'."
  }
}
