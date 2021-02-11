resource "null_resource" "worker_disks" {
  count = length(var.ssh.worker_addresses)

  connection {
    type        = "ssh"
    user        = var.ssh.user
    private_key = var.ssh.private_key
    host        = var.ssh.worker_addresses[count.index]
  }

  provisioner "remote-exec" {
    inline = ["mkdir -p /root/bootstrap/"]
  }

  provisioner "file" {
    source      = "${path.module}/assets/portworx_disk_setup.sh"
    destination = "/root/bootstrap/portworx_disk_setup.sh"

  }
  provisioner "remote-exec" {
    inline = [
      "bash /root/bootstrap/portworx_disk_setup.sh"
    ]
  }
}

locals {
  portworx_version = try(length(var.portworx_version) ? var.portworx_version
  : var.latest_portworx_version, var.latest_portworx_version)
}

resource "null_resource" "install_portworx" {
  depends_on = [
    null_resource.worker_disks
  ]
  connection {
    type        = "ssh"
    user        = var.ssh.user
    private_key = var.ssh.private_key
    host        = var.ssh.host
  }

  provisioner "remote-exec" {
    inline = [
      "VER=$(kubectl version --short | awk -Fv '/Server Version: / {print $3}')",
      "URL='https://install.portworx.com/${local.portworx_version}?mc=false&kbver='$VER'&b=true&j=auto&kd=${urlencode("/dev/pwx_vg/pwxkvdb")}&c=${var.cluster_name}&stork=true&st=k8s&pp=IfNotPresent'",
      "kubectl --kubeconfig ${var.ssh.kubeconfig} apply -f $URL"
    ]
  }
}

resource "null_resource" "license_portworx" {
  count = length(var.portworx_license) > 0 ? 1 : 0

  depends_on = [
    null_resource.install_portworx
  ]
  connection {
    type        = "ssh"
    user        = var.ssh.user
    private_key = var.ssh.private_key
    host        = var.ssh.worker_addresses[0]
  }

  provisioner "remote-exec" {
    inline = [
      "/opt/pwx/bin/pxctl license activate ${var.portworx_license}"
    ]
  }
}
