variable "storage_module" {
  description = "The name of the Storage provider module (ex. \"rook\")"
  default     = ""
}

variable "storage_options" {
  type        = any
  description = "Options for the Storage provider module. Option names can be found in the documentation for each module and are prefixed with the vendor name (\"portworx_version\")"
  default     = {}
}

variable "cluster_name" {
  type        = string
  description = "Name of the cluster"
}

variable "ssh" {
  description = "SSH options for the storage provider including SSH details to access the control plane including the remote path to the kubeconfig file and a list of worker addresses."

  type = object({
    host             = string
    private_key      = string
    user             = string
    kubeconfig       = string
    worker_addresses = list(string)
  })
}
