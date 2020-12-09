provider "packet" {
  auth_token = var.auth_token
}

resource "random_string" "cluster_suffix" {
  length  = 5
  special = false
  upper   = false
}

resource "packet_project" "new_project" {
  count           = var.create_project ? 1 : 0
  name            = var.project_name
  organization_id = var.organization_id
  bgp_config {
    deployment_type = "local"
    asn             = var.bgp_asn
  }
}

locals {
  cp_count            = var.ha_control_plane ? 3 : 1
  cluster_name        = format("%s-%s", var.cluster_name, random_string.cluster_suffix.result)
  timestamp           = timestamp()
  timestamp_sanitized = replace(local.timestamp, "/[- TZ:]/", "")
  ssh_key_name        = format("bm-cluster-%s", local.timestamp_sanitized)
  project_id          = var.create_project ? packet_project.new_project[0].id : var.project_id
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

resource "packet_reserved_ip_block" "cp_vip" {
  project_id  = local.project_id
  facility    = var.facility
  quantity    = 1
  description = format("Cluster: '%s' Contol Plane VIP", local.cluster_name)
}

resource "packet_reserved_ip_block" "ingress_vip" {
  project_id  = local.project_id
  facility    = var.facility
  quantity    = 1
  description = format("Cluster: '%s' Ingress VIP", local.cluster_name)
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
  project_id       = local.project_id
  user_data        = file("templates/user_data.sh")
  tags             = ["anthos", "baremetal", "control-plane"]
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
  project_id       = local.project_id
  user_data        = file("templates/user_data.sh")
  tags             = ["anthos", "baremetal", "worker"]
}

resource "packet_bgp_session" "enable_cp_bgp" {
  count          = local.cp_count
  device_id      = element(packet_device.control_plane.*.id, count.index)
  address_family = "ipv4"
}

resource "packet_bgp_session" "enable_worker_bgp" {
  count          = var.worker_count
  device_id      = element(packet_device.worker_nodes.*.id, count.index)
  address_family = "ipv4"
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
  template = file("templates/pre_reqs.sh")
  vars = {
    cluster_name     = local.cluster_name
    operating_system = var.operating_system
    cp_vip           = cidrhost(packet_reserved_ip_block.cp_vip.cidr_notation, 0)
    ingress_vip      = cidrhost(packet_reserved_ip_block.ingress_vip.cidr_notation, 0)
    cp_ips           = join(" ", packet_device.control_plane.*.access_public_ipv4)
    worker_ips       = join(" ", packet_device.worker_nodes.*.access_public_ipv4)
    anthos_ver       = var.anthos_version
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
    destination = "/root/baremetal/pre_reqs.sh"
  }

  provisioner "remote-exec" {
    inline = ["bash /root/baremetal/pre_reqs.sh"]
  }
}

resource "null_resource" "deploy_anthos_cluster" {
  depends_on = [
    packet_bgp_session.enable_cp_bgp,
    packet_bgp_session.enable_worker_bgp,
    null_resource.prep_anthos_cluster,
    null_resource.write_ssh_private_key
  ]
  connection {
    type        = "ssh"
    user        = "root"
    private_key = chomp(tls_private_key.ssh_key_pair.private_key_pem)
    host        = packet_device.control_plane.0.access_public_ipv4
  }
  provisioner "remote-exec" {
    inline = [
      "cd /root/baremetal/",
      "export GOOGLE_APPLICATION_CREDENTIALS=/root/baremetal/keys/super-admin.json",
      "/root/baremetal/bmctl create cluster -c ${local.cluster_name} --force"
    ]
  }
}

data "template_file" "template_kube_vip_install" {
  count    = var.ha_control_plane ? 2 : 1
  template = file("templates/kube_vip_install.sh")
  vars = {
    cluster_name = local.cluster_name
    eip          = cidrhost(packet_reserved_ip_block.cp_vip.cidr_notation, 0)
    count        = count.index
    kube_vip_ver = var.kube_vip_version
  }
}

data "template_file" "template_kube_vip_install_workers" {
  template = file("templates/kube_vip_install.sh")
  vars = {
    cluster_name = local.cluster_name
    eip          = cidrhost(packet_reserved_ip_block.cp_vip.cidr_notation, 0)
    count        = 3
    kube_vip_ver = var.kube_vip_version
  }
}


resource "null_resource" "kube_vip_install_first_cp" {
  depends_on = [
    packet_bgp_session.enable_cp_bgp,
    packet_bgp_session.enable_worker_bgp,
    null_resource.prep_anthos_cluster,
    null_resource.write_ssh_private_key
  ]
  connection {
    type        = "ssh"
    user        = "root"
    private_key = chomp(tls_private_key.ssh_key_pair.private_key_pem)
    host        = packet_device.control_plane.0.access_public_ipv4
  }
  provisioner "file" {
    content     = data.template_file.template_kube_vip_install.0.rendered
    destination = "/root/baremetal/kube_vip_install.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "bash /root/baremetal/kube_vip_install.sh"
    ]
  }
}


data "template_file" "add_remaining_cps" {
  count    = var.ha_control_plane ? 1 : 0
  template = file("templates/add_remaining_cps.sh")
  vars = {
    cluster_name = local.cluster_name
    cp_2         = packet_device.control_plane.1.access_public_ipv4
    cp_3         = packet_device.control_plane.2.access_public_ipv4
  }
}

resource "null_resource" "add_remaining_cps" {
  count = var.ha_control_plane ? 1 : 0
  depends_on = [
    null_resource.deploy_anthos_cluster,
    null_resource.kube_vip_install_first_cp
  ]
  connection {
    type        = "ssh"
    user        = "root"
    private_key = chomp(tls_private_key.ssh_key_pair.private_key_pem)
    host        = packet_device.control_plane.0.access_public_ipv4
  }
  provisioner "file" {
    content     = data.template_file.add_remaining_cps.0.rendered
    destination = "/root/baremetal/add_remaining_cps.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "bash /root/baremetal/add_remaining_cps.sh"
    ]
  }
}

resource "null_resource" "kube_vip_install_remaining_cp" {
  count = var.ha_control_plane ? 2 : 0
  depends_on = [
    null_resource.add_remaining_cps
  ]
  connection {
    type        = "ssh"
    user        = "root"
    private_key = chomp(tls_private_key.ssh_key_pair.private_key_pem)
    host        = element(packet_device.control_plane.*.access_public_ipv4, count.index + 1)
  }
  provisioner "remote-exec" {
    inline = ["mkdir -p /root/baremetal"]
  }
  provisioner "file" {
    content     = data.template_file.template_kube_vip_install.1.rendered
    destination = "/root/baremetal/kube_vip_install.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "bash /root/baremetal/kube_vip_install.sh"
    ]
  }
}

resource "null_resource" "kube_vip_install_workers" {
  count = var.worker_count
  depends_on = [
    null_resource.kube_vip_install_remaining_cp
  ]
  connection {
    type        = "ssh"
    user        = "root"
    private_key = chomp(tls_private_key.ssh_key_pair.private_key_pem)
    host        = element(packet_device.worker_nodes.*.access_public_ipv4, count.index)
  }
  provisioner "remote-exec" {
    inline = ["mkdir -p /root/baremetal"]
  }
  provisioner "file" {
    content     = data.template_file.template_kube_vip_install_workers.rendered
    destination = "/root/baremetal/kube_vip_install.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "bash /root/baremetal/kube_vip_install.sh"
    ]
  }
}

data "template_file" "ccm_secret" {
  template = file("templates/ccm_secret.yaml")
  vars = {
    auth_token = var.auth_token
    project_id = local.project_id
  }
}

resource "null_resource" "install_ccm" {
  depends_on = [
    null_resource.kube_vip_install_workers
  ]
  connection {
    type        = "ssh"
    user        = "root"
    private_key = chomp(tls_private_key.ssh_key_pair.private_key_pem)
    host        = packet_device.control_plane.0.access_public_ipv4
  }
  provisioner "file" {
    content     = data.template_file.ccm_secret.rendered
    destination = "/root/baremetal/ccm_secret.yaml"
  }
  provisioner "remote-exec" {
    inline = [
      "kubectl --kubeconfig /root/baremetal/bmctl-workspace/${local.cluster_name}/${local.cluster_name}-kubeconfig apply -f /root/baremetal/ccm_secret.yaml",
      "kubectl --kubeconfig /root/baremetal/bmctl-workspace/${local.cluster_name}/${local.cluster_name}-kubeconfig apply -f ${var.ccm_deploy_url}"
    ]
  }
}

resource "null_resource" "download_kube_config" {
  depends_on = [null_resource.deploy_anthos_cluster]

  provisioner "local-exec" {
    command = "scp -i ~/.ssh/${local.ssh_key_name} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null  root@${packet_device.control_plane.0.access_public_ipv4}:/root/baremetal/bmctl-workspace/${local.cluster_name}/${local.cluster_name}-kubeconfig ."
  }
}

