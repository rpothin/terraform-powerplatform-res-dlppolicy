terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    powerplatform = {
      source  = "microsoft/power-platform"
      version = "~> 4.0"
    }
  }
}

provider "powerplatform" {
  # Configuration is provided via environment variables:
  #   POWER_PLATFORM_TENANT_ID
  #   POWER_PLATFORM_CLIENT_ID
  # For OIDC: ARM_USE_OIDC=true
}
