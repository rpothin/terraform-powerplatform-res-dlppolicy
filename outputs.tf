output "resource_id" {
  description = "The unique ID (GUID) of the DLP policy."
  value       = powerplatform_data_loss_prevention_policy.this.id
}

output "display_name" {
  description = "The display name of the DLP policy."
  value       = powerplatform_data_loss_prevention_policy.this.display_name
}

output "unmatched_business_connector_ids" {
  description = "Business connector IDs that were not returned by the provider connector catalog. An empty set confirms that all configured business connectors were found."
  value       = local.unmatched_business_connector_ids
}

output "resource" {
  description = "The full DLP policy resource object. Exposes all provider-managed attributes not surfaced by dedicated outputs."
  value       = powerplatform_data_loss_prevention_policy.this
}
