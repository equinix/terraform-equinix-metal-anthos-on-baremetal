terraform {
  required_providers {
    null = {
      source = "hashicorp/null"
    }
    packet = {
      source = "packethost/packet"
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
  }
  required_version = ">= 0.13"
}
