variable "auth_token" {
  type        = string
  description = "Packet API Key"
}

variable "project_id" {
  type        = string
  description = "Packet Project ID"
}

variable "hostname" {
  type        = string
  default     = "anthos-baremetal"
  description = "Hostname for the nodes"
}

variable "facility" {
  type        = string
  default     = "ny5"
  description = "Packet Facility to deploy into"
}

variable "plan" {
  type        = string
  default     = "c3.small.x86"
  description = "Packet device type to deploy"
}

variable "ha_control_plane" {
  type        = bool
  description = "Do you want a highly available control plane"
  default     = true
}

variable "worker_count" {
  type        = number
  description = "Number of baremetal worker nodes"
  default     = 3
}

variable "operating_system" {
  type        = string
  description = "The Operating system of the node"
  default     = "ubuntu_20_04"
}

variable "billing_cycle" {
  type        = string
  description = "How the node will be billed (Not usually changed)"
  default     = "hourly"
}

variable "private_subnet" {
  type        = string
  description = "Private IP Space to use for Layer2"
  default     = "172.29.254.0/24"
}

variable "cluster_name" {
  type        = string
  description = "The GKE cluster name"
  default     = "equinix-metal-gke-cluster"
}
