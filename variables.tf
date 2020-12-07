variable "auth_token" {
  type        = string
  description = "Equinix Metal API Key"
}

variable "project_id" {
  type        = string
  default     = "null"
  description = "Equinix Metal Project ID"
}

variable "organization_id" {
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
  default     = "equinix-metal-gke-cluster"
  description = "The GKE cluster name"
}

variable "create_project" {
  type        = bool
  default     = true
  description = "Create a Project if this is 'true'. Else use provided 'project_id'"
}

variable "project_name" {
  type        = string
  default     = "baremetal-anthos"
  description = "The name of the project if 'create_project' is 'true'."
}

variable "bgp_asn" {
  type        = number
  default     = 65000
  description = "BGP ASN to peer with Equinix Metal"
}

