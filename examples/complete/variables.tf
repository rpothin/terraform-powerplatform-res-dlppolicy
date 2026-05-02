variable "name" {
  description = "The name of the resource."
  type        = string
  default     = "example-complete"
}

variable "location" {
  description = "The geographic location for the resource."
  type        = string
  default     = "unitedstates"
}

variable "tags" {
  description = "A map of tags to apply to the resource."
  type        = map(string)
  default = {
    environment = "development"
    project     = "power-platform-module"
    managed_by  = "terraform"
  }
}
