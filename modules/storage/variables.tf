variable "storage_module" {
  description = "The name of the Storage provider module (ex. \"portworx\")"
  default     = ""
}

variable "storage_options" {
  type        = any
  description = "Options for the Storage provider module"
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
