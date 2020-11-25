provider "packet" {
  auth_token = var.auth_token
}


resource "random_string" "cluster_suffix" {
  length  = 5
  special = false
  upper   = false
}

locals {
  cp_count            = var.ha_control_plane ? 3 : 1
  cluster_name        = format("%s-%s", var.cluster_name, random_string.cluster_suffix.result)
  timestamp           = timestamp()
  timestamp_sanitized = replace(local.timestamp, "/[- TZ:]/", "")
  ssh_key_name        = format("bm-cluster-%s", local.timestamp_sanitized)
}

resource "packet_vlan" "private_vlan" {
  facility    = var.facility
  project_id  = var.project_id
  description = "Private Network"
}

resource "tls_private_key" "ssh_key_pair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "packet_ssh_key" "ssh_pub_key" {
  name       = local.cluster_name
  public_key = chomp(tls_private_key.ssh_key_pair.public_key_openssh)
}

resource "local_file" "cluster_private_key_pem" {
  content         = chomp(tls_private_key.ssh_key_pair.private_key_pem)
  filename        = pathexpand(format("~/.ssh/%s", local.ssh_key_name))
  file_permission = "0600"
}

data "template_file" "control_plane_user_data" {
  count    = local.cp_count
  template = file("templates/user_data.sh")
  vars = {
    operating_system = var.operating_system
    ip_address       = cidrhost(var.private_subnet, count.index + 1)
    netmask          = cidrnetmask(var.private_subnet)
  }
}

data "template_file" "worker_user_data" {
  count    = var.worker_count
  template = file("templates/user_data.sh")
  vars = {
    operating_system = var.operating_system
    ip_address       = cidrhost(var.private_subnet, local.cp_count + count.index + 1)
    netmask          = cidrnetmask(var.private_subnet)
  }
}

resource "packet_device" "control_plane" {
  depends_on = [
    packet_ssh_key.ssh_pub_key
  ]
  count            = local.cp_count
  hostname         = format("%s-cp-%02d", local.cluster_name, count.index + 1)
  plan             = var.cp_plan
  facilities       = [var.facility]
  operating_system = var.operating_system
  billing_cycle    = var.billing_cycle
  project_id       = var.project_id
  tags             = ["anthos", "baremetal", cidrhost(var.private_subnet, count.index + 1)]
  user_data        = element(data.template_file.control_plane_user_data.*.rendered, count.index)
}

resource "packet_device" "worker_nodes" {
  depends_on = [
    packet_ssh_key.ssh_pub_key
  ]
  count            = var.worker_count
  hostname         = format("%s-worker-%02d", local.cluster_name, count.index + 1)
  plan             = var.worker_plan
  facilities       = [var.facility]
  operating_system = var.operating_system
  billing_cycle    = var.billing_cycle
  project_id       = var.project_id
  tags             = ["anthos", "baremetal", cidrhost(var.private_subnet, local.cp_count + count.index + 1)]
  user_data        = element(data.template_file.worker_user_data.*.rendered, count.index)
}

resource "packet_device_network_type" "control_plane" {
  count     = local.cp_count
  device_id = element(packet_device.control_plane.*.id, count.index)
  type      = "hybrid"
}

resource "packet_device_network_type" "worker_nodes" {
  count     = var.worker_count
  device_id = element(packet_device.worker_nodes.*.id, count.index)
  type      = "hybrid"
}

resource "packet_port_vlan_attachment" "control_plane_vlan_attach" {
  count     = local.cp_count
  device_id = element(packet_device_network_type.control_plane.*.id, count.index)
  port_name = "eth1"
  vlan_vnid = packet_vlan.private_vlan.vxlan
}

resource "packet_port_vlan_attachment" "worker_vlan_attach" {
  count     = var.worker_count
  device_id = element(packet_device_network_type.worker_nodes.*.id, count.index)
  port_name = "eth1"
  vlan_vnid = packet_vlan.private_vlan.vxlan
}

resource "null_resource" "write_ssh_private_key" {
  connection {
    type        = "ssh"
    user        = "root"
    private_key = chomp(tls_private_key.ssh_key_pair.private_key_pem)
    host        = packet_device.control_plane.0.access_public_ipv4
  }

  provisioner "file" {
    content     = chomp(tls_private_key.ssh_key_pair.private_key_pem)
    destination = "/root/.ssh/id_rsa"
  }
  provisioner "remote-exec" {
    inline = ["chmod 0400 /root/.ssh/id_rsa"]
  }
}

data "template_file" "deploy_anthos_cluster" {
  template = file("templates/deploy_cluster.sh")
  vars = {
    cluster_name = local.cluster_name
  }
}

data "template_file" "update_cluster_vars" {
  template = file("templates/update_cluster_vars.py")
  vars = {
    private_subnet = var.private_subnet
    cp_count       = local.cp_count
    worker_count   = var.worker_count
    cluster_name   = local.cluster_name
  }
}

resource "null_resource" "prep_anthos_cluster" {
  connection {
    type        = "ssh"
    user        = "root"
    private_key = chomp(tls_private_key.ssh_key_pair.private_key_pem)
    host        = packet_device.control_plane.0.access_public_ipv4
  }

  provisioner "remote-exec" {
    inline = ["mkdir -p /root/baremetal/keys/"]
  }

  provisioner "file" {
    source      = "util/keys/"
    destination = "/root/baremetal/keys"
  }

  provisioner "file" {
    content     = data.template_file.deploy_anthos_cluster.rendered
    destination = "/root/baremetal/deploy_cluster.sh"
  }

  provisioner "file" {
    content     = data.template_file.update_cluster_vars.rendered
    destination = "/root/baremetal/update_cluster_vars.py"
  }

  provisioner "remote-exec" {
    inline = ["bash /root/baremetal/deploy_cluster.sh"]
  }
}

resource "null_resource" "deploy_anthos_cluster" {
  depends_on = [
    packet_port_vlan_attachment.control_plane_vlan_attach,
    packet_port_vlan_attachment.worker_vlan_attach,
    null_resource.prep_anthos_cluster
  ]
  connection {
    type        = "ssh"
    user        = "root"
    private_key = chomp(tls_private_key.ssh_key_pair.private_key_pem)
    host        = packet_device.control_plane.0.access_public_ipv4
  }
  provisioner "remote-exec" {
    inline = [
      "python3 /root/baremetal/update_cluster_vars.py",
      "cd /root/baremetal/",
      "export GOOGLE_APPLICATION_CREDENTIALS=/root/baremetal/keys/super-admin.json",
      "/root/baremetal/bmctl create cluster -c ${local.cluster_name} --force"
    ]
  }
}
