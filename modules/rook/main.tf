locals {
  rook_version = try(length(var.rook_version) ? var.rook_version
  : var.latest_rook_version, var.latest_rook_version)
}

resource "null_resource" "install_rook" {
  connection {
    type        = "ssh"
    user        = var.ssh.user
    private_key = var.ssh.private_key
    host        = var.ssh.host
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /$HOME/bootstrap/",
      "cd /$HOME/bootstrap/",
      "wget https://github.com/rook/rook/archive/refs/tags/${local.rook_version}.tar.gz",
      "tar -xf ${local.rook_version}.tar.gz",
      "mv rook-* rook",
      "cd rook/cluster/examples/kubernetes/ceph",
      "kubectl create -f crds.yaml -f common.yaml -f operator.yaml",
      "sleep 5",
      "kubectl create -f cluster.yaml",
      "sleep 5",
      "kubectl create -f csi/rbd/storageclass.yaml",
      "sleep 5",
      "kubectl patch storageclass rook-ceph-block -p '{\"metadata\": {\"annotations\":{\"storageclass.kubernetes.io/is-default-class\":\"true\"}}}'"
    ]
  }
}