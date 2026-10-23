# This test uses the real provider. The HTTP 404 assertion is also checked by
# assert-missing-policy-fails.sh because Terraform expect_failures cannot match
# the provider diagnostic text.

run "connectors_only_missing_policy_fails_at_live_lookup" {
  command = plan

  variables {
    display_name       = "tftest-missing-policy"
    environment_type   = "OnlyEnvironments"
    management_mode    = "connectors_only"
    existing_policy_id = "f57a0b7d-51b9-4f2c-8fa5-bb0f3f3f8b8a"
  }

  expect_failures = [
    data.powerplatform_rest_query.live_policy[0],
  ]
}
