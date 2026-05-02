variable "name" {
  description = "The name of the resource. Used as a display name or identifier."
  type        = string

  validation {
    condition     = length(var.name) > 0 && length(var.name) <= 256
    error_message = "Name must be between 1 and 256 characters."
  }
}

variable "location" {
  description = "The geographic location for the resource (e.g., 'unitedstates', 'europe', 'asia')."
  type        = string

  # TODO: Update this list when Microsoft adds new Power Platform regions,
  # or replace with a data source lookup / more lenient validation for your module.
  validation {
    condition     = contains(["unitedstates", "europe", "asia", "australia", "japan", "india", "canada", "southamerica", "unitedkingdom", "france", "germany", "switzerland", "norway", "korea", "southafrica", "uae", "singapore"], var.location)
    error_message = "Location must be a valid Power Platform region."
  }
}

variable "tags" {
  description = "A map of tags to apply to the resource."
  type        = map(string)
  default     = {}
}
