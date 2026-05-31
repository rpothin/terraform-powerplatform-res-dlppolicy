locals {
  # Flat list of all live DLP policies; populated only when management_mode = "connectors_only".
  # Uses the flatten+for pattern so that when count = 0 (full mode) the result is safely [].
  _all_live_policies = flatten([
    for d in data.powerplatform_data_loss_prevention_policies.current : d.policies
  ])

  # Zero-or-one-element list of the live policy whose id matches existing_policy_id.
  # A lifecycle precondition guarantees this is non-empty at apply time in connectors_only mode.
  # Comparison is case-insensitive: GUIDs from the API and from the user may differ in case.
  # The null guard ensures the lower() call is never applied to a null value when
  # existing_policy_id is not set (full mode or precondition 3 not yet evaluated).
  _live_matched_policy = [
    for p in local._all_live_policies : p
    if var.existing_policy_id != null && lower(p.id) == lower(var.existing_policy_id)
  ]

  # Environment list passed to the resource:
  # - full mode: var.environments (sorted deterministically by the resource attribute).
  # - connectors_only mode: live environment set from the API, converted to a list for sort().
  #   Falls back to [] if no match; the lifecycle precondition guarantees a match at apply time.
  effective_environments = (
    var.management_mode == "connectors_only"
    ? (length(local._live_matched_policy) > 0 ? tolist(local._live_matched_policy[0].environments) : [])
    : var.environments
  )


  # Set of business connector IDs for fast membership checks
  business_connector_ids = toset([for c in var.business_connectors : c.id])

  # Unblockable connectors not explicitly assigned to the Business group are
  # placed in the NonBusiness group. This ensures the "Blocked" default
  # classification never incorrectly targets connectors that cannot be blocked.
  # Sorting by ID before toset() ensures a deterministic element order, preventing
  # spurious "update-in-place" noise in plans when nothing has actually changed.
  non_business_connectors = toset([
    for c_id in sort([
      for c in data.powerplatform_connectors.all.connectors : c.id
      if c.unblockable && !contains(local.business_connector_ids, c.id)
      ]) : {
      id                           = c_id
      default_action_rule_behavior = ""
      action_rules                 = []
      endpoint_rules               = []
    }
  ])

  # Blockable connectors not assigned to the Business group are explicitly
  # placed in the Blocked group. The provider requires every connector to
  # appear in exactly one group — relying on default_connectors_classification
  # alone is insufficient and will cause a provider error.
  blocked_connectors = toset([
    for c_id in sort([
      for c in data.powerplatform_connectors.all.connectors : c.id
      if !c.unblockable && !contains(local.business_connector_ids, c.id)
      ]) : {
      id                           = c_id
      default_action_rule_behavior = ""
      action_rules                 = []
      endpoint_rules               = []
    }
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
