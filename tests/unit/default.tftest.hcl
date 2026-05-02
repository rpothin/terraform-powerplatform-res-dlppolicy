# Unit tests — uses mock provider, no credentials required.

mock_provider "powerplatform" {}

run "default_connectors_classification_is_blocked" {
  command = plan

  variables {
    display_name = "test-policy"
  }

  assert {
    condition     = powerplatform_data_loss_prevention_policy.this.default_connectors_classification == "Blocked"
    error_message = "default_connectors_classification must always be 'Blocked' for zero-trust compliance."
  }
}

run "custom_connectors_wildcard_block_is_always_added" {
  command = plan

  variables {
    display_name = "test-policy"
  }

  assert {
    condition     = anytrue([for p in powerplatform_data_loss_prevention_policy.this.custom_connectors_patterns : p.host_url_pattern == "*" && p.data_group == "Blocked"])
    error_message = "A wildcard catch-all Blocked pattern must always be present in custom_connectors_patterns."
  }
}

run "custom_connectors_user_pattern_preserved" {
  command = plan

  variables {
    display_name = "test-policy"
    custom_connectors_patterns = [
      {
        order            = 1
        host_url_pattern = "https://api.example.com/*"
        data_group       = "Business"
      }
    ]
  }

  assert {
    condition     = anytrue([for p in powerplatform_data_loss_prevention_policy.this.custom_connectors_patterns : p.host_url_pattern == "https://api.example.com/*" && p.data_group == "Business"])
    error_message = "User-supplied custom connector patterns must be preserved."
  }

  assert {
    condition     = anytrue([for p in powerplatform_data_loss_prevention_policy.this.custom_connectors_patterns : p.host_url_pattern == "*" && p.data_group == "Blocked"])
    error_message = "Wildcard Blocked pattern must still be appended after user-supplied patterns."
  }
}

# ---------------------------------------------------------------------------
# Environment scope tests
# ---------------------------------------------------------------------------

run "all_environments_scope" {
  command = plan

  variables {
    display_name     = "test-policy"
    environment_type = "AllEnvironments"
  }

  assert {
    condition     = powerplatform_data_loss_prevention_policy.this.environment_type == "AllEnvironments"
    error_message = "environment_type should be AllEnvironments."
  }
}

run "only_environments_scope" {
  command = plan

  variables {
    display_name     = "test-policy"
    environment_type = "OnlyEnvironments"
    environments     = ["00000000-0000-0000-0000-000000000001"]
  }

  assert {
    condition     = powerplatform_data_loss_prevention_policy.this.environment_type == "OnlyEnvironments"
    error_message = "environment_type should be OnlyEnvironments."
  }
}

run "except_environments_scope" {
  command = plan

  variables {
    display_name     = "test-policy"
    environment_type = "ExceptEnvironments"
    environments     = ["00000000-0000-0000-0000-000000000001"]
  }

  assert {
    condition     = powerplatform_data_loss_prevention_policy.this.environment_type == "ExceptEnvironments"
    error_message = "environment_type should be ExceptEnvironments."
  }
}

# ---------------------------------------------------------------------------
# Connector classification tests (connector data overridden per run)
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Connector classification tests
# ---------------------------------------------------------------------------

run "non_business_connectors_empty_when_no_connectors_mocked" {
  command = plan

  variables {
    display_name = "test-policy"
  }

  # Mock provider returns no connectors — non_business_connectors is empty.
  # In real deployments, the data source returns all connectors and the module
  # automatically places unblockable ones in this group. Full connector
  # classification is covered by integration tests.
  assert {
    condition     = length(powerplatform_data_loss_prevention_policy.this.non_business_connectors) == 0
    error_message = "non_business_connectors must be empty when the data source returns no connectors."
  }
}

run "business_connector_excluded_from_non_business" {
  command = plan

  variables {
    display_name = "test-policy"
    business_connectors = [
      { id = "/providers/Microsoft.PowerApps/apis/shared_logicflows" },
    ]
  }

  # shared_logicflows is unblockable but listed as Business — must NOT appear in NonBusiness.
  assert {
    condition     = !contains([for c in powerplatform_data_loss_prevention_policy.this.non_business_connectors : c.id], "/providers/Microsoft.PowerApps/apis/shared_logicflows")
    error_message = "A connector added to business_connectors must not appear in the NonBusiness group."
  }
}

# ---------------------------------------------------------------------------
# Variable validation tests
# ---------------------------------------------------------------------------

run "rejects_empty_display_name" {
  command = plan

  variables {
    display_name = ""
  }

  expect_failures = [
    var.display_name,
  ]
}

run "rejects_invalid_environment_type" {
  command = plan

  variables {
    display_name     = "test-policy"
    environment_type = "InvalidType"
  }

  expect_failures = [
    var.environment_type,
  ]
}

run "rejects_invalid_environment_uuid" {
  command = plan

  variables {
    display_name     = "test-policy"
    environment_type = "OnlyEnvironments"
    environments     = ["not-a-valid-uuid"]
  }

  expect_failures = [
    var.environments,
  ]
}

run "rejects_empty_business_connector_id" {
  command = plan

  variables {
    display_name = "test-policy"
    business_connectors = [
      { id = "" },
    ]
  }

  expect_failures = [
    var.business_connectors,
  ]
}

run "rejects_invalid_custom_pattern_data_group" {
  command = plan

  variables {
    display_name = "test-policy"
    custom_connectors_patterns = [
      {
        order            = 1
        host_url_pattern = "https://api.example.com/*"
        data_group       = "InvalidGroup"
      }
    ]
  }

  expect_failures = [
    var.custom_connectors_patterns,
  ]
}

run "rejects_zero_order_in_custom_pattern" {
  command = plan

  variables {
    display_name = "test-policy"
    custom_connectors_patterns = [
      {
        order            = 0
        host_url_pattern = "https://api.example.com/*"
        data_group       = "Business"
      }
    ]
  }

  expect_failures = [
    var.custom_connectors_patterns,
  ]
}

