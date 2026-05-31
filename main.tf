data "powerplatform_connectors" "all" {}

# Test
# Fetches all live DLP policies to read the current environment membership.
# Only provisioned in connectors_only mode to avoid unnecessary API calls in full mode.
data "powerplatform_data_loss_prevention_policies" "current" {
  count = var.management_mode == "connectors_only" ? 1 : 0
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
      condition     = var.management_mode != "connectors_only" || var.existing_policy_id == null || length(local._live_matched_policy) > 0
      error_message = "management_mode 'connectors_only': no live DLP policy found matching existing_policy_id. Verify the ID is correct and the policy exists in the tenant."
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
      toset([for c in data.powerplatform_connectors.all.connectors : c.id])
    )) == 0
    error_message = "One or more business_connectors IDs do not exist in the list of available connectors. Verify the connector IDs are correct and the PowerPlatform provider has access to list connectors."
  }
}
