variable "display_name" {
  description = "The display name of the DLP policy."
  type        = string
  nullable    = false

  validation {
    condition     = length(var.display_name) > 0 && length(var.display_name) <= 256
    error_message = "display_name must be between 1 and 256 characters."
  }
}

variable "default_connectors_classification" {
  description = "The classification applied to connectors not explicitly assigned to the Business or NonBusiness groups. Defaults to 'Blocked' for a zero-trust baseline. Set to 'Business' or 'NonBusiness' only when explicitly relaxing the policy."
  type        = string
  nullable    = false
  default     = "Blocked"

  validation {
    condition     = contains(["Blocked", "Business", "NonBusiness"], var.default_connectors_classification)
    error_message = "default_connectors_classification must be one of: Blocked, Business, NonBusiness."
  }
}


variable "environment_type" {
  description = "The environment scope for the policy. 'OnlyEnvironments' (default) restricts the policy to the environments listed in `environments`. 'ExceptEnvironments' applies it to all environments except those listed. 'AllEnvironments' applies the policy tenant-wide — this is the most dangerous scope, requires Global Admin, and takes effect immediately across the entire tenant."
  type        = string
  nullable    = false
  default     = "OnlyEnvironments"

  validation {
    condition     = contains(["AllEnvironments", "ExceptEnvironments", "OnlyEnvironments"], var.environment_type)
    error_message = "environment_type must be one of: AllEnvironments, ExceptEnvironments, OnlyEnvironments."
  }
}

variable "environments" {
  description = "A list of environment IDs to include or exclude depending on environment_type. Required when environment_type is OnlyEnvironments or ExceptEnvironments. Each value must be a valid UUID (case-insensitive). Use lower() in HCL to normalise IDs copied from the Power Platform admin center."
  type        = list(string)
  nullable    = false
  default     = []

  validation {
    condition     = alltrue([for e in var.environments : can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", e))])
    error_message = "All environment IDs must be valid UUIDs in the format xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (case-insensitive)."
  }
}

variable "business_connectors" {
  description = "A set of connectors to classify as Business (permitted for use with sensitive business data). Unblockable connectors not listed here are automatically placed in the NonBusiness group. All remaining connectors default to Blocked."
  type = set(object({
    id                           = string
    default_action_rule_behavior = optional(string, "")
    action_rules = optional(list(object({
      action_id = string
      behavior  = string
    })), [])
    endpoint_rules = optional(list(object({
      order    = number
      endpoint = string
      behavior = string
    })), [])
  }))
  nullable = false
  default  = []

  validation {
    condition     = alltrue([for c in var.business_connectors : length(c.id) > 0])
    error_message = "Each business connector must have a non-empty id."
  }

  validation {
    condition     = alltrue([for c in var.business_connectors : c.default_action_rule_behavior == "" || contains(["Allow", "Block"], c.default_action_rule_behavior)])
    error_message = "Each business connector default_action_rule_behavior must be empty, 'Allow', or 'Block'."
  }

  validation {
    condition     = alltrue([for c in var.business_connectors : alltrue([for r in c.action_rules : contains(["Allow", "Block"], r.behavior)])])
    error_message = "Each business connector action_rule behavior must be 'Allow' or 'Block'."
  }

  validation {
    condition     = alltrue([for c in var.business_connectors : alltrue([for r in c.endpoint_rules : contains(["Allow", "Deny"], r.behavior)])])
    error_message = "Each business connector endpoint_rule behavior must be 'Allow' or 'Deny'."
  }
}

variable "custom_connectors_patterns" {
  description = "Additional custom connector host URL patterns and their data group classification. Rules are evaluated in ascending order. A catch-all Blocked pattern (*) is always appended as the final rule to block all unmatched custom connectors."
  type = set(object({
    order            = number
    host_url_pattern = string
    data_group       = string
  }))
  nullable = false
  default  = []

  validation {
    condition     = alltrue([for p in var.custom_connectors_patterns : contains(["Business", "NonBusiness", "Blocked", "Ignore"], p.data_group)])
    error_message = "Each custom connector pattern data_group must be one of: Business, NonBusiness, Blocked, Ignore."
  }

  validation {
    condition     = alltrue([for p in var.custom_connectors_patterns : p.order > 0])
    error_message = "Each custom connector pattern order must be a positive integer."
  }

  validation {
    condition     = alltrue([for p in var.custom_connectors_patterns : p.host_url_pattern != "*"])
    error_message = "The wildcard pattern '*' is reserved and is always appended automatically as the final Blocked rule. Remove it from custom_connectors_patterns."
  }

  validation {
    condition     = alltrue([for p in var.custom_connectors_patterns : length(p.host_url_pattern) > 0])
    error_message = "Each custom connector pattern host_url_pattern must be non-empty."
  }
}
