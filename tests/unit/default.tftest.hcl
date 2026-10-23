# Unit tests — uses mock provider, no credentials required.

mock_provider "powerplatform" {}

run "default_connectors_classification_is_blocked" {
  command = plan

  variables {
    display_name     = "test-policy"
    environment_type = "AllEnvironments"
  }

  assert {
    condition     = powerplatform_data_loss_prevention_policy.this.default_connectors_classification == "Blocked"
    error_message = "default_connectors_classification must always be 'Blocked' for zero-trust compliance."
  }
}

run "custom_connectors_wildcard_block_is_always_added" {
  command = plan

  variables {
    display_name     = "test-policy"
    environment_type = "AllEnvironments"
  }

  assert {
    condition     = anytrue([for p in powerplatform_data_loss_prevention_policy.this.custom_connectors_patterns : p.host_url_pattern == "*" && p.data_group == "Blocked"])
    error_message = "A wildcard catch-all Blocked pattern must always be present in custom_connectors_patterns."
  }
}

run "custom_connectors_user_pattern_preserved" {
  command = plan

  variables {
    display_name     = "test-policy"
    environment_type = "AllEnvironments"
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

run "default_environment_type_is_only_environments" {
  command = plan

  variables {
    display_name = "test-policy"
    environments = ["00000000-0000-0000-0000-000000000001"]
    # environment_type intentionally omitted — testing the module default
  }

  assert {
    condition     = powerplatform_data_loss_prevention_policy.this.environment_type == "OnlyEnvironments"
    error_message = "Default environment_type must be 'OnlyEnvironments' to enforce safe-by-default scoping."
  }
}

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
    environments = [
      "00000000-0000-0000-0000-000000000002",
      "00000000-0000-0000-0000-000000000001",
    ]
  }

  assert {
    condition     = powerplatform_data_loss_prevention_policy.this.environment_type == "OnlyEnvironments"
    error_message = "environment_type should be OnlyEnvironments."
  }

  assert {
    condition     = data.powerplatform_connectors.all.environment_id == "00000000-0000-0000-0000-000000000002"
    error_message = "OnlyEnvironments policies must scope the connector catalog to the first configured environment."
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

  assert {
    condition     = data.powerplatform_connectors.all.environment_id == null
    error_message = "ExceptEnvironments policies must retain the tenant-level connector catalog scope."
  }
}

# ---------------------------------------------------------------------------
# Connector classification tests
# ---------------------------------------------------------------------------

run "non_business_connectors_empty_when_no_connectors_mocked" {
  command = plan

  variables {
    display_name     = "test-policy"
    environment_type = "AllEnvironments"
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
    display_name     = "test-policy"
    environment_type = "AllEnvironments"
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

  assert {
    condition     = contains(output.unmatched_business_connector_ids, "/providers/Microsoft.PowerApps/apis/shared_logicflows")
    error_message = "unmatched_business_connector_ids must expose business connector IDs missing from the catalog."
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

# ---------------------------------------------------------------------------
# default_connectors_classification variable tests
# ---------------------------------------------------------------------------

run "rejects_invalid_default_connectors_classification" {
  command = plan

  variables {
    display_name                      = "test-policy"
    environment_type                  = "AllEnvironments"
    default_connectors_classification = "Invalid"
  }

  expect_failures = [
    var.default_connectors_classification,
  ]
}

run "accepts_non_blocked_default_classification" {
  command = plan

  variables {
    display_name                      = "test-policy"
    environment_type                  = "AllEnvironments"
    default_connectors_classification = "General"
  }

  assert {
    condition     = powerplatform_data_loss_prevention_policy.this.default_connectors_classification == "General"
    error_message = "default_connectors_classification = General must be accepted and passed through to the resource."
  }
}

# ---------------------------------------------------------------------------
# Lifecycle precondition tests
# ---------------------------------------------------------------------------

run "rejects_only_environments_without_environments_list" {
  command = plan

  variables {
    display_name     = "test-policy"
    environment_type = "OnlyEnvironments"
    # environments intentionally omitted — should trigger the lifecycle precondition
  }

  expect_failures = [
    powerplatform_data_loss_prevention_policy.this,
  ]
}

run "rejects_except_environments_without_environments_list" {
  command = plan

  variables {
    display_name     = "test-policy"
    environment_type = "ExceptEnvironments"
    # environments intentionally omitted — should trigger the lifecycle precondition
  }

  expect_failures = [
    powerplatform_data_loss_prevention_policy.this,
  ]
}

# ---------------------------------------------------------------------------
# management_mode = connectors_only tests
# ---------------------------------------------------------------------------
# Mock responses cover decoding and preconditions. The mock provider cannot
# simulate HTTP 404; that behavior is covered by a real-provider integration test.

run "connectors_only_rejected_for_all_environments" {
  command = plan

  variables {
    display_name       = "test-policy"
    environment_type   = "AllEnvironments"
    management_mode    = "connectors_only"
    existing_policy_id = "11111111-1111-1111-1111-111111111111"
  }

  override_data {
    target = data.powerplatform_rest_query.live_policy[0]

    values = {
      output = {
        body = jsonencode({
          policyDefinition = {
            name         = "11111111-1111-1111-1111-111111111111"
            environments = []
          }
        })
      }
    }
  }

  expect_failures = [
    powerplatform_data_loss_prevention_policy.this,
  ]
}

run "connectors_only_rejected_for_except_environments" {
  command = plan

  variables {
    display_name       = "test-policy"
    environment_type   = "ExceptEnvironments"
    management_mode    = "connectors_only"
    existing_policy_id = "11111111-1111-1111-1111-111111111111"
  }

  override_data {
    target = data.powerplatform_rest_query.live_policy[0]

    values = {
      output = {
        body = jsonencode({
          policyDefinition = {
            name         = "11111111-1111-1111-1111-111111111111"
            environments = []
          }
        })
      }
    }
  }

  expect_failures = [
    powerplatform_data_loss_prevention_policy.this,
  ]
}

run "connectors_only_rejected_without_existing_policy_id" {
  command = plan

  variables {
    display_name     = "test-policy"
    environment_type = "OnlyEnvironments"
    management_mode  = "connectors_only"
    # existing_policy_id intentionally omitted — should trigger precondition 3
  }

  assert {
    condition     = length(data.powerplatform_rest_query.live_policy) == 0
    error_message = "An unset existing_policy_id must not create a REST query with a malformed URL."
  }

  expect_failures = [
    powerplatform_data_loss_prevention_policy.this,
  ]
}

run "connectors_only_rejects_mismatched_policy_identity" {
  command = plan

  variables {
    display_name       = "test-policy"
    environment_type   = "OnlyEnvironments"
    management_mode    = "connectors_only"
    existing_policy_id = "A1111111-1111-1111-1111-111111111111"
  }

  override_data {
    target = data.powerplatform_rest_query.live_policy[0]

    values = {
      output = {
        body = jsonencode({
          policyDefinition = {
            name         = "33333333-3333-3333-3333-333333333333"
            environments = []
          }
        })
      }
    }
  }

  expect_failures = [
    powerplatform_data_loss_prevention_policy.this,
  ]
}

run "connectors_only_uses_live_environment_membership" {
  command = plan

  variables {
    display_name       = "test-policy"
    environment_type   = "OnlyEnvironments"
    management_mode    = "connectors_only"
    existing_policy_id = "A1111111-1111-1111-1111-111111111111"
  }

  override_data {
    target = data.powerplatform_rest_query.live_policy[0]

    values = {
      output = {
        body = jsonencode({
          policyDefinition = {
            name = "a1111111-1111-1111-1111-111111111111"
            environments = [
              { name = "aaaaaaaa-0000-0000-0000-000000000002" },
              { name = "aaaaaaaa-0000-0000-0000-000000000001" },
            ]
          }
        })
      }
    }
  }

  assert {
    condition     = toset(powerplatform_data_loss_prevention_policy.this.environments) == toset(["aaaaaaaa-0000-0000-0000-000000000001", "aaaaaaaa-0000-0000-0000-000000000002"])
    error_message = "connectors_only mode must preserve the live policy environments returned by the API."
  }

  assert {
    condition     = data.powerplatform_connectors.all.environment_id == "aaaaaaaa-0000-0000-0000-000000000001"
    error_message = "connectors_only mode must scope the connector catalog to the lowest live environment ID."
  }

  assert {
    condition     = data.powerplatform_rest_query.live_policy[0].url == "https://api.bap.microsoft.com/providers/PowerPlatform.Governance/v2/policies/a1111111-1111-1111-1111-111111111111"
    error_message = "The live policy lookup must use the public BAP host and a normalized policy ID in its URL."
  }

  assert {
    condition     = data.powerplatform_rest_query.live_policy[0].scope == "https://service.powerapps.com/.default"
    error_message = "The live policy lookup must use the public-cloud Power Apps scope by default."
  }

  assert {
    condition     = data.powerplatform_rest_query.live_policy[0].method == "GET" && data.powerplatform_rest_query.live_policy[0].expected_http_status == toset([200])
    error_message = "The live policy lookup must issue a GET and accept only HTTP 200."
  }
}

run "connectors_only_preserves_explicitly_empty_live_environment_list" {
  command = plan

  variables {
    display_name       = "test-policy"
    environment_type   = "OnlyEnvironments"
    management_mode    = "connectors_only"
    existing_policy_id = "11111111-1111-1111-1111-111111111111"
  }

  override_data {
    target = data.powerplatform_rest_query.live_policy[0]

    values = {
      output = {
        body = jsonencode({
          policyDefinition = {
            name         = "11111111-1111-1111-1111-111111111111"
            environments = []
          }
        })
      }
    }
  }

  assert {
    condition     = length(powerplatform_data_loss_prevention_policy.this.environments) == 0
    error_message = "A valid API response with an explicitly empty environments array must remain empty."
  }

  assert {
    condition     = data.powerplatform_connectors.all.environment_id == null
    error_message = "An empty live environment list must keep the tenant-level connector catalog scope."
  }
}

run "connectors_only_rejects_response_without_environments" {
  command = plan

  variables {
    display_name       = "test-policy"
    environment_type   = "OnlyEnvironments"
    management_mode    = "connectors_only"
    existing_policy_id = "11111111-1111-1111-1111-111111111111"
  }

  override_data {
    target = data.powerplatform_rest_query.live_policy[0]

    values = {
      output = {
        body = jsonencode({
          policyDefinition = {
            name = "11111111-1111-1111-1111-111111111111"
          }
        })
      }
    }
  }

  expect_failures = [
    powerplatform_data_loss_prevention_policy.this,
  ]
}

run "connectors_only_rejects_null_environments" {
  command = plan

  variables {
    display_name       = "test-policy"
    environment_type   = "OnlyEnvironments"
    management_mode    = "connectors_only"
    existing_policy_id = "11111111-1111-1111-1111-111111111111"
  }

  override_data {
    target = data.powerplatform_rest_query.live_policy[0]

    values = {
      output = {
        body = jsonencode({
          policyDefinition = {
            name         = "11111111-1111-1111-1111-111111111111"
            environments = null
          }
        })
      }
    }
  }

  expect_failures = [
    powerplatform_data_loss_prevention_policy.this,
  ]
}

run "connectors_only_rejects_malformed_environment_entries" {
  command = plan

  variables {
    display_name       = "test-policy"
    environment_type   = "OnlyEnvironments"
    management_mode    = "connectors_only"
    existing_policy_id = "11111111-1111-1111-1111-111111111111"
  }

  override_data {
    target = data.powerplatform_rest_query.live_policy[0]

    values = {
      output = {
        body = jsonencode({
          policyDefinition = {
            name         = "11111111-1111-1111-1111-111111111111"
            environments = [{ id = "aaaaaaaa-0000-0000-0000-000000000001" }]
          }
        })
      }
    }
  }

  expect_failures = [
    powerplatform_data_loss_prevention_policy.this,
  ]
}

run "rejects_invalid_existing_policy_id_uuid" {
  command = plan

  variables {
    display_name       = "test-policy"
    environment_type   = "AllEnvironments"
    existing_policy_id = "not-a-valid-uuid"
  }

  expect_failures = [
    var.existing_policy_id,
  ]
}

run "rejects_bapi_host_with_scheme_or_path" {
  command = plan

  variables {
    display_name     = "test-policy"
    environment_type = "AllEnvironments"
    bapi_host        = "https://api.bap.microsoft.com/"
  }

  expect_failures = [
    var.bapi_host,
  ]
}

run "rejects_empty_bapi_scope" {
  command = plan

  variables {
    display_name     = "test-policy"
    environment_type = "AllEnvironments"
    bapi_scope       = "  "
  }

  expect_failures = [
    var.bapi_scope,
  ]
}

run "full_mode_environments_from_var_not_api" {
  command = plan

  # management_mode = "full" (default) — data source count=0, mock_data default is irrelevant.
  variables {
    display_name       = "test-policy"
    environment_type   = "OnlyEnvironments"
    management_mode    = "full"
    existing_policy_id = "11111111-1111-1111-1111-111111111111"
    environments       = ["aaaaaaaa-0000-0000-0000-000000000001"]
  }

  assert {
    condition     = contains(tolist(powerplatform_data_loss_prevention_policy.this.environments), "aaaaaaaa-0000-0000-0000-000000000001")
    error_message = "full mode must use var.environments as the environment source."
  }

  assert {
    condition     = length(powerplatform_data_loss_prevention_policy.this.environments) == 1
    error_message = "full mode must have exactly 1 environment (from var.environments)."
  }

  assert {
    condition     = length(data.powerplatform_rest_query.live_policy) == 0
    error_message = "full mode must not make a live policy REST request."
  }

  # existing_policy_id is set in full mode — the check advisory should fire.
  expect_failures = [
    check.existing_policy_id_unused_in_full_mode,
  ]
}
