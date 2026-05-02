variable "display_name" {
  description = "The display name of the DLP policy."
  type        = string
  default     = "example-complete-dlp-policy"
}

variable "environment_type" {
  description = "The environment scope for the policy."
  type        = string
  default     = "OnlyEnvironments"
}

variable "environments" {
  description = "A list of environment IDs the policy applies to."
  type        = list(string)
  default = [
    "00000000-0000-0000-0000-000000000001",
    "00000000-0000-0000-0000-000000000002",
  ]
}

variable "business_connectors" {
  description = "Connectors to classify as Business."
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
  default = [
    # Microsoft SharePoint Online
    { id = "/providers/Microsoft.PowerApps/apis/shared_sharepointonline" },
    # Microsoft Teams
    { id = "/providers/Microsoft.PowerApps/apis/shared_teams" },
  ]
}

variable "custom_connectors_patterns" {
  description = "Additional custom connector host URL patterns."
  type = set(object({
    order            = number
    host_url_pattern = string
    data_group       = string
  }))
  default = [
    # Allow internal APIs on the corporate domain for Business use
    {
      order            = 1
      host_url_pattern = "https://api.contoso.com/*"
      data_group       = "Business"
    },
  ]
}
