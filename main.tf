data "powerplatform_connectors" "all" {}

resource "powerplatform_data_loss_prevention_policy" "this" {
  display_name                      = var.display_name
  default_connectors_classification = "Blocked"
  environment_type                  = var.environment_type
  environments                      = sort(var.environments)

  business_connectors     = var.business_connectors
  non_business_connectors = local.non_business_connectors
  blocked_connectors      = local.blocked_connectors

  custom_connectors_patterns = local.custom_connectors_patterns_with_default_block

  lifecycle {
    precondition {
      condition     = var.environment_type == "AllEnvironments" || length(var.environments) > 0
      error_message = "environments must contain at least one environment ID when environment_type is OnlyEnvironments or ExceptEnvironments."
    }
  }
}

check "business_connector_ids_exist" {
  assert {
    condition = length(setsubtract(
      local.business_connector_ids,
      toset([for c in data.powerplatform_connectors.all.connectors : c.id])
    )) == 0
    error_message = "One or more business_connectors IDs do not exist in the list of available connectors. Verify the connector IDs are correct and the PowerPlatform provider has access to list connectors."
  }
}
