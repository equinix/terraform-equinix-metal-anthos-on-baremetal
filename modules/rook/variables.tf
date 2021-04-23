variable "rook_version" {
  type        = string
  description = "The version of Rook to install (latest_rook_version will be used if not set)"
  default     = ""
}

variable "latest_rook_version" {
  type        = string
  description = "The version of Rook to install"
  default     = "v1.5.10"
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
