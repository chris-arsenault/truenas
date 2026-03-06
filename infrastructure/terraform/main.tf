terraform {
  required_version = ">= 1.14"
  required_providers {
    truenas = {
      source  = "dariusbakunas/truenas"
      version = "~> 0.11"
    }
  }
}

provider "truenas" {
  api_key  = var.truenas_api_key
  base_url = var.truenas_base_url
}
