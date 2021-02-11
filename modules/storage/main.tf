module "portworx" {
  count            = var.storage_module == "portworx" ? 1 : 0
  source           = "../portworx"
  portworx_version = try(var.storage_options.version, null)
  ssh              = var.ssh
  cluster_name     = var.cluster_name
}
