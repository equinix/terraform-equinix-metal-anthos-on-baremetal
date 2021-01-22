terraform {
  required_providers {
    null = {
      source = "hashicorp/null"
    }
    metal = {
      source = "equinix/metal"
    }
    random = {
      source = "hashicorp/random"
    }
    template = {
      source = "hashicorp/template"
    }
    tls = {
      source = "hashicorp/tls"
    }
    local = {
      source = "hashicorp/local"
    }
    google = {
      source  = "hashicorp/google"
      version = "~>3.53.0"
    }
  }
  required_version = ">= 0.13"
}
