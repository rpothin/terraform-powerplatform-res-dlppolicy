locals {
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
