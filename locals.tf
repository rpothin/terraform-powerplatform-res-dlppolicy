locals {
  # The response is fetched only in connectors_only mode when an ID is supplied.
  # jsondecode and required attribute access intentionally have no empty-list fallback.
  _live_policy = (
    length(data.powerplatform_rest_query.live_policy) > 0
    ? jsondecode(data.powerplatform_rest_query.live_policy[0].output.body).policyDefinition
    : null
  )

  # An explicitly empty environments array is valid; absent, null, or malformed
  # environment data must fail its resource precondition.
  _live_policy_environments_valid = (
    length(data.powerplatform_rest_query.live_policy) == 0
    ? true
    : try(
      local._live_policy.environments != null &&
      alltrue([
        for environment in local._live_policy.environments :
        environment.name != null && length(trimspace(environment.name)) > 0
      ]),
      false
    )
  )

  # Environment list passed to the resource:
  # - full mode: var.environments (sorted deterministically by the resource attribute).
  # - connectors_only mode: live environment names from the single-policy API response.
  effective_environments = (
    var.management_mode == "connectors_only"
    ? (length(data.powerplatform_rest_query.live_policy) > 0
      ? (local._live_policy_environments_valid
        ? [for environment in local._live_policy.environments : environment.name]
      : [])
    : [])
    : var.environments
  )

  # A concrete environment exposes the complete connector catalog for
  # OnlyEnvironments policies. Other policy types retain the provider's
  # tenant-level default because they have no single environment scope.
  _connector_catalog_environment_id = (
    var.environment_type != "OnlyEnvironments"
    ? null
    : var.management_mode == "connectors_only"
    ? (local._live_policy_environments_valid
      ? (length(local.effective_environments) > 0 ? sort(local.effective_environments)[0] : null)
    : null)
    : (length(var.environments) > 0 ? var.environments[0] : null)
  )

  # Canonicalize provider connector IDs before deriving DLP classifications.
  # A connector is unblockable if any duplicate provider record marks it as unblockable.
  all_connector_ids = toset([
    for c in data.powerplatform_connectors.all.connectors : c.id
  ])
  unblockable_connector_ids = toset([
    for c in data.powerplatform_connectors.all.connectors : c.id if c.unblockable
  ])
  blockable_connector_ids = setsubtract(local.all_connector_ids, local.unblockable_connector_ids)

  # Set of business connector IDs for fast membership checks
  business_connector_ids = toset([for c in var.business_connectors : c.id])

  unmatched_business_connector_ids = sort(tolist(setsubtract(
    local.business_connector_ids,
    local.all_connector_ids
  )))

  # Unblockable connectors not explicitly assigned to the Business group are
  # placed in the NonBusiness group. This ensures the "Blocked" default
  # classification never incorrectly targets connectors that cannot be blocked.
  # Sorting canonical IDs before toset() ensures deterministic element order,
  # preventing spurious "update-in-place" noise when nothing has changed.
  non_business_connectors = toset([
    for c_id in sort(tolist(local.unblockable_connector_ids)) : {
      id                           = c_id
      default_action_rule_behavior = ""
      action_rules                 = []
      endpoint_rules               = []
    } if !contains(local.business_connector_ids, c_id)
  ])

  # Blockable connectors not assigned to the Business group are explicitly
  # placed in the Blocked group. The provider requires every connector to
  # appear in exactly one group — relying on default_connectors_classification
  # alone is insufficient and will cause a provider error.
  blocked_connectors = toset([
    for c_id in sort(tolist(local.blockable_connector_ids)) : {
      id                           = c_id
      default_action_rule_behavior = ""
      action_rules                 = []
      endpoint_rules               = []
    } if !contains(local.business_connector_ids, c_id)
  ])

  # Highest order value in user-supplied custom connector patterns (0 when none).
  max_custom_pattern_order = length(var.custom_connectors_patterns) > 0 ? max([for p in var.custom_connectors_patterns : p.order]...) : 0

  # Append a wildcard Blocked rule after all user-supplied patterns so that
  # every custom connector is blocked unless explicitly matched by an earlier rule.
  custom_connectors_patterns_with_default_block = setunion(
    var.custom_connectors_patterns,
    toset([{
      order            = local.max_custom_pattern_order + 1
      host_url_pattern = "*"
      data_group       = "Blocked"
    }])
  )
}
