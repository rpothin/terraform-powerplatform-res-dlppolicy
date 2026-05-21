module "this" {
  source  = "rpothin/res-dlppolicy/powerplatform"

  display_name     = var.display_name
  environment_type = var.environment_type
  environments     = var.environments
}
