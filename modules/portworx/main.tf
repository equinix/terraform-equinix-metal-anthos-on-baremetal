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
      "URL='https://install.portworx.com/${var.portworx_version}?mc=false&kbver='$VER'&b=true&j=auto&kd=${urlencode("/dev/pwx_vg/pwxkvdb")}&c=${var.cluster_name}&stork=true&st=k8s&pp=IfNotPresent'",
      "kubectl --kubeconfig ${var.ssh.kubeconfig} apply -f $URL"
    ]
  }
}
