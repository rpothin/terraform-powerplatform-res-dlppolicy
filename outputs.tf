output "resource_id" {
  description = "The unique ID (GUID) of the DLP policy."
  value       = powerplatform_data_loss_prevention_policy.this.id
}

output "display_name" {
  description = "The display name of the DLP policy."
  value       = powerplatform_data_loss_prevention_policy.this.display_name
}

output "resource" {
  description = "The full DLP policy resource object. Exposes all provider-managed attributes not surfaced by dedicated outputs."
  value       = powerplatform_data_loss_prevention_policy.this
}
