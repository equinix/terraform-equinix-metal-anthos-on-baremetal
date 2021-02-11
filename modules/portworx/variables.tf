variable "portworx_version" {
  type        = string
  description = "The version of Portworx to install (latest_portworx_version will be used if not set)"
  default     = ""
}

variable "latest_portworx_version" {
  type        = string
  description = "The version of Portworx to install"
  default     = "2.6"
}

variable "cluster_name" {
  type        = string
  description = "Name of the cluster"
}

variable "ssh" {
  description = "SSH options for the storage provider including SSH details to access the control plane including the remote path to the kubeconfig file and a list of worker addresses"

  type = object({
    host             = string
    private_key      = string
    user             = string
    kubeconfig       = string
    worker_addresses = list(string)
  })
}
