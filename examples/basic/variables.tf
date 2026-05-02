variable "display_name" {
  description = "The display name of the DLP policy."
  type        = string
  default     = "example-basic-dlp-policy"
}

variable "environment_type" {
  description = "The environment scope for the policy. Defaults to 'AllEnvironments' to demonstrate tenant-wide scope in this example. For production use, prefer 'OnlyEnvironments' with explicit environment IDs."
  type        = string
  default     = "AllEnvironments"
}

variable "environments" {
  description = "A list of environment IDs. Not required when environment_type is 'AllEnvironments'."
  type        = list(string)
  default     = []
}
