# TODO (before publishing): Replace the source path below with the Terraform Registry
# address once the module is published, e.g.:
#   source  = "rpothin/<module-name>/powerplatform"
#   version = "~> 0.1"
# See: https://developer.hashicorp.com/terraform/language/modules/develop/structure#examples
module "this" {
  source = "../../" # local path for development — update to registry address before publishing

  display_name     = var.display_name
  environment_type = var.environment_type
  environments     = var.environments
}
