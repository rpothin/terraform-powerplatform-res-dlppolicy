output "resource_id" {
  description = "The unique ID (GUID) of the DLP policy."
  value       = module.this.resource_id
}

output "display_name" {
  description = "The display name of the DLP policy."
  value       = module.this.display_name
}
