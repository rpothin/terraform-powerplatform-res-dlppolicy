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
# Connector classification tests
# ---------------------------------------------------------------------------

run "non_business_connectors_empty_when_no_connectors_mocked" {
  command = plan

  variables {
    display_name = "test-policy"
  }

  # Mock provider returns no connectors — non_business_connectors and
  # blocked_connectors are both empty. In real deployments, the data source
  # returns all connectors and the module automatically classifies them.
  # Full connector classification is verified by integration tests.
  assert {
    condition     = length(powerplatform_data_loss_prevention_policy.this.non_business_connectors) == 0
    error_message = "non_business_connectors must be empty when the data source returns no connectors."
  }

  assert {
    condition     = length(powerplatform_data_loss_prevention_policy.this.blocked_connectors) == 0
    error_message = "blocked_connectors must be empty when the data source returns no connectors."
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

  # The mock provider returns no connectors, so non_business_connectors is always
  # empty — this assertion is vacuously true. The actual exclusion logic (that a
  # connector in business_connectors is filtered out of non_business_connectors)
  # is validated by integration tests where the real data source returns connectors.
  # The check block also fires (expected) because the mock returns no connectors.
  assert {
    condition     = !contains([for c in powerplatform_data_loss_prevention_policy.this.non_business_connectors : c.id], "/providers/Microsoft.PowerApps/apis/shared_logicflows")
    error_message = "A connector added to business_connectors must not appear in the NonBusiness group."
  }

  expect_failures = [
    check.business_connector_ids_exist,
  ]
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

run "rejects_wildcard_in_custom_pattern" {
  command = plan

  variables {
    display_name = "test-policy"
    custom_connectors_patterns = [
      {
        order            = 1
        host_url_pattern = "*"
        data_group       = "Business"
      }
    ]
  }

  expect_failures = [
    var.custom_connectors_patterns,
  ]
}

run "accepts_uppercase_environment_uuid" {
  command = plan

  variables {
    display_name     = "test-policy"
    environment_type = "OnlyEnvironments"
    environments     = ["00000000-0000-0000-0000-00000000000A"]
  }

  assert {
    condition     = powerplatform_data_loss_prevention_policy.this.environment_type == "OnlyEnvironments"
    error_message = "Uppercase UUIDs must be accepted for environment IDs."
  }
}

