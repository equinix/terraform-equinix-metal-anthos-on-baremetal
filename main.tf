provider "packet" {
  auth_token = var.auth_token
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
  name       = var.hostname
  public_key = chomp(tls_private_key.ssh_key_pair.public_key_openssh)
}

data "template_file" "user_data" {
  count    = var.node_count
  template = file("templates/user_data.sh")
  vars = {
    operating_system = var.operating_system
    ip_address       = cidrhost(var.private_subnet, count.index + 1)
    netmask          = cidrnetmask(var.private_subnet)
  }
}

resource "packet_device" "baremetal_anthos" {
  depends_on = [
    packet_ssh_key.ssh_pub_key
  ]
  count            = var.node_count
  hostname         = format("%s-%02d", var.hostname, count.index + 1)
  plan             = var.plan
  facilities       = [var.facility]
  operating_system = var.operating_system
  billing_cycle    = var.billing_cycle
  project_id       = var.project_id
  tags             = ["anthos", "baremetal", cidrhost(var.private_subnet, count.index + 1)]
  user_data        = element(data.template_file.user_data.*.rendered, count.index)
}


resource "packet_device_network_type" "baremetal_anthos" {
  count     = var.node_count
  device_id = element(packet_device.baremetal_anthos.*.id, count.index)
  type      = "hybrid"
}

resource "packet_port_vlan_attachment" "vlan_attach" {
  count     = var.node_count
  device_id = element(packet_device_network_type.baremetal_anthos.*.id, count.index)
  port_name = "eth1"
  vlan_vnid = packet_vlan.private_vlan.vxlan
}

resource "null_resource" "write_ssh_private_key" {
  connection {
    type        = "ssh"
    user        = "root"
    private_key = chomp(tls_private_key.ssh_key_pair.private_key_pem)
    host        = packet_device.baremetal_anthos.0.access_public_ipv4
  }

  provisioner "file" {
    content     = chomp(tls_private_key.ssh_key_pair.private_key_pem)
    destination = "/root/.ssh/id_rsa"
  }
  provisioner "remote-exec" {
    inline = ["chmod 0400 /root/.ssh/id_rsa"]
  }
}
