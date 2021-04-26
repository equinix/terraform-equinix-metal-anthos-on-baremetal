variable "metal_auth_token" {
  type        = string
  description = "Equinix Metal API Key"
}

variable "metal_project_id" {
  type        = string
  default     = "null"
  description = "Equinix Metal Project ID"
}

variable "metal_organization_id" {
  type        = string
  default     = "null"
  description = "Equinix Metal Organization ID"
}

variable "hostname" {
  type        = string
  default     = "anthos-baremetal"
  description = "Hostname for the nodes"
}

variable "facility" {
  type        = string
  default     = "ny5"
  description = "Equinix Metal Facility to deploy into"
}

variable "cp_plan" {
  type        = string
  default     = "c3.small.x86"
  description = "Equinix Metal device type to deploy control plane nodes"
}

variable "worker_plan" {
  type        = string
  default     = "c3.small.x86"
  description = "Equinix Metal device type to deploy for worker nodes"
}

variable "ha_control_plane" {
  type        = bool
  default     = true
  description = "Do you want a highly available control plane"
}

variable "worker_count" {
  type        = number
  default     = 3
  description = "Number of baremetal worker nodes"
}

variable "operating_system" {
  type        = string
  default     = "ubuntu_20_04"
  description = "The Operating system of the node"
}

variable "billing_cycle" {
  type        = string
  default     = "hourly"
  description = "How the node will be billed (Not usually changed)"
}

variable "cluster_name" {
  type        = string
  default     = "eqnx-metal-gke"
  description = "The GKE cluster name"
  validation {
    condition     = length(var.cluster_name) <= 15
    error_message = "Cluster name length must be 15 characters or less."
  }
}

variable "metal_create_project" {
  type        = bool
  default     = true
  description = "Create a Metal Project if this is 'true'. Else use provided 'metal_project_id'"
}

variable "metal_project_name" {
  type        = string
  default     = "baremetal-anthos"
  description = "The name of the Metal project if 'create_project' is 'true'."
}

variable "gcp_project_id" {
  type        = string
  description = "The GCP project ID to use"
}

variable "gcp_keys_path" {
  type        = string
  default     = ""
  description = "The path to a directory that contains the required GCP service account keys"
}

# Advanced Variables below this line

variable "bgp_asn" {
  type        = number
  default     = 65000
  description = "BGP ASN to peer with Equinix Metal"
}

variable "ccm_version" {
  type        = string
  default     = "v2.0.0"
  description = "The version of the Equinix Metal CCM"
}

variable "kube_vip_version" {
  type        = string
  default     = "0.2.3"
  description = "The version of Kube-VIP to use"
}

variable "anthos_version" {
  type        = string
  default     = "1.7.0"
  description = "The version of Google Anthos to install"
}

variable "ccm_deploy_url" {
  type        = string
  default     = "https://gist.githubusercontent.com/thebsdbox/c86dd970549638105af8d96439175a59/raw/4abf90fb7929ded3f7a201818efbb6164b7081f0/ccm.yaml"
  description = "The deploy url for the Equinix Metal CCM"
}

variable "kube_vip_daemonset_url" {
  type        = string
  default     = "https://raw.githubusercontent.com/plunder-app/kube-vip/bb7d2da73eeb6c4712479b007ff931a12180e626/docs/manifests/kube-vip-em.yaml"
  description = "The deploy url for the Kube-VIP Daemonset"
}

variable "storage_module" {
  type        = string
  description = "The name of the storage module to enable. If set, use storage_options."
  default     = ""
}

variable "storage_options" {
  type        = any
  description = "Options specific to the storage module. Check the documentation for the storage module for details."
  default     = null
}
