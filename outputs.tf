output "resource_id" {
  description = "The unique ID (GUID) of the DLP policy."
  value       = powerplatform_data_loss_prevention_policy.this.id
}

output "display_name" {
  description = "The display name of the DLP policy."
  value       = powerplatform_data_loss_prevention_policy.this.display_name
}
