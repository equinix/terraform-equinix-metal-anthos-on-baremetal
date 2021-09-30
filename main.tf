provider "metal" {
  auth_token = var.metal_auth_token
}

provider "google" {
  project = var.gcp_project_id
}

resource "random_string" "cluster_suffix" {
  length  = 5
  special = false
  upper   = false
}

resource "metal_project" "new_project" {
  count           = var.metal_create_project ? 1 : 0
  name            = var.metal_project_name
  organization_id = var.metal_organization_id
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
  ssh_key_name        = format("anthos-%s-%s", var.cluster_name, random_string.cluster_suffix.result)
  metal_project_id    = var.metal_create_project ? metal_project.new_project[0].id : var.metal_project_id
  gcr_sa_key          = var.gcp_keys_path == "" ? base64decode(google_service_account_key.gcr_sa_key[0].private_key) : file("${var.gcp_keys_path}/gcr.json")
  connect_sa_key      = var.gcp_keys_path == "" ? base64decode(google_service_account_key.connect_sa_key[0].private_key) : file("${var.gcp_keys_path}/connect.json")
  register_sa_key     = var.gcp_keys_path == "" ? base64decode(google_service_account_key.register_sa_key[0].private_key) : file("${var.gcp_keys_path}/register.json")
  cloud_ops_sa_key    = var.gcp_keys_path == "" ? base64decode(google_service_account_key.cloud_ops_sa_key[0].private_key) : file("${var.gcp_keys_path}/cloud-ops.json")
  bmctl_sa_key        = var.gcp_keys_path == "" ? base64decode(google_service_account_key.bmctl_sa_key[0].private_key) : file("${var.gcp_keys_path}/bmctl.json")
  ccm_deploy_url      = format("https://github.com/equinix/cloud-provider-equinix-metal/releases/download/%s/deployment.yaml", var.ccm_version)
}

resource "tls_private_key" "ssh_key_pair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "metal_ssh_key" "ssh_pub_key" {
  name       = local.cluster_name
  public_key = chomp(tls_private_key.ssh_key_pair.public_key_openssh)
}

resource "local_file" "cluster_private_key_pem" {
  content         = chomp(tls_private_key.ssh_key_pair.private_key_pem)
  filename        = pathexpand(format("~/.ssh/%s", local.ssh_key_name))
  file_permission = "0600"
}

resource "metal_reserved_ip_block" "cp_vip" {
  project_id  = local.metal_project_id
  facility    = var.facility
  quantity    = 1
  description = format("Cluster: '%s' Contol Plane VIP", local.cluster_name)
}

resource "metal_reserved_ip_block" "ingress_vip" {
  project_id  = local.metal_project_id
  facility    = var.facility
  quantity    = 1
  description = format("Cluster: '%s' Ingress VIP", local.cluster_name)
}

data "template_file" "user_data" {
  template = file("${path.module}/templates/user_data.sh")
  vars = {
    operating_system = var.operating_system
  }
}

resource "metal_device" "control_plane" {
  depends_on = [
    metal_ssh_key.ssh_pub_key
  ]
  count            = local.cp_count
  hostname         = format("%s-cp-%02d", local.cluster_name, count.index + 1)
  plan             = var.cp_plan
  facilities       = [var.facility]
  operating_system = var.operating_system
  billing_cycle    = var.billing_cycle
  project_id       = local.metal_project_id
  user_data        = data.template_file.user_data.rendered
  tags             = ["anthos", "baremetal", "control-plane"]
}

resource "metal_device" "worker_nodes" {
  depends_on = [
    metal_ssh_key.ssh_pub_key
  ]
  count            = var.worker_count
  hostname         = format("%s-worker-%02d", local.cluster_name, count.index + 1)
  plan             = var.worker_plan
  facilities       = [var.facility]
  operating_system = var.operating_system
  billing_cycle    = var.billing_cycle
  project_id       = local.metal_project_id
  user_data        = data.template_file.user_data.rendered
  tags             = ["anthos", "baremetal", "worker"]
}

resource "metal_bgp_session" "enable_cp_bgp" {
  count          = local.cp_count
  device_id      = element(metal_device.control_plane.*.id, count.index)
  address_family = "ipv4"
}

resource "metal_bgp_session" "enable_worker_bgp" {
  count          = var.worker_count
  device_id      = element(metal_device.worker_nodes.*.id, count.index)
  address_family = "ipv4"
}

resource "null_resource" "write_ssh_private_key" {
  connection {
    type        = "ssh"
    user        = "root"
    private_key = chomp(tls_private_key.ssh_key_pair.private_key_pem)
    host        = metal_device.control_plane.0.access_public_ipv4
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
  template = file("${path.module}/templates/pre_reqs.sh")
  vars = {
    cluster_name     = local.cluster_name
    operating_system = var.operating_system
    cp_vip           = cidrhost(metal_reserved_ip_block.cp_vip.cidr_notation, 0)
    ingress_vip      = cidrhost(metal_reserved_ip_block.ingress_vip.cidr_notation, 0)
    cp_ips           = join(" ", metal_device.control_plane.*.access_private_ipv4)
    cp_ids           = join(" ", metal_device.control_plane.*.id)
    worker_ips       = join(" ", metal_device.worker_nodes.*.access_private_ipv4)
    worker_ids       = join(" ", metal_device.worker_nodes.*.id)
    anthos_ver       = var.anthos_version
  }
}

data "template_file" "pre_reqs_worker" {
  template = file("${path.module}/templates/pre_reqs_worker.sh")
  vars = {
    operating_system = var.operating_system
  }
}

resource "null_resource" "prep_anthos_cluster" {
  depends_on = [
    google_project_service.enabled-apis
  ]

  connection {
    type        = "ssh"
    user        = "root"
    private_key = chomp(tls_private_key.ssh_key_pair.private_key_pem)
    host        = metal_device.control_plane.0.access_public_ipv4
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /root/baremetal/keys/",
      "mkdir -p /root/bootstrap/"
    ]
  }

  provisioner "file" {
    content     = local.gcr_sa_key
    destination = "/root/baremetal/keys/gcr.json"
  }

  provisioner "file" {
    content     = local.connect_sa_key
    destination = "/root/baremetal/keys/connect.json"
  }

  provisioner "file" {
    content     = local.register_sa_key
    destination = "/root/baremetal/keys/register.json"
  }

  provisioner "file" {
    content     = local.cloud_ops_sa_key
    destination = "/root/baremetal/keys/cloud-ops.json"
  }

  provisioner "file" {
    content     = local.bmctl_sa_key
    destination = "/root/baremetal/keys/bmctl.json"
  }

  provisioner "file" {
    content     = data.template_file.deploy_anthos_cluster.rendered
    destination = "/root/bootstrap/pre_reqs.sh"
  }

  provisioner "remote-exec" {
    inline = ["bash /root/bootstrap/pre_reqs.sh"]
  }
}

data "template_file" "create_cluster" {
  template = file("${path.module}/templates/create_cluster.sh")
  vars = {
    cluster_name = local.cluster_name
  }
}

// Initialize Anthos on the first control plane node.
// This will also trigger installs (including apt)
// on the worker nodes.
resource "null_resource" "deploy_anthos_cluster" {
  depends_on = [
    null_resource.prep_anthos_cluster,
    null_resource.write_ssh_private_key
  ]
  connection {
    type        = "ssh"
    user        = "root"
    private_key = chomp(tls_private_key.ssh_key_pair.private_key_pem)
    host        = metal_device.control_plane.0.access_public_ipv4
  }

  provisioner "file" {
    content     = data.template_file.create_cluster.rendered
    destination = "/root/bootstrap/create_cluster.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "bash /root/bootstrap/create_cluster.sh"
    ]
  }
}

resource "null_resource" "download_kube_config" {
  depends_on = [null_resource.deploy_anthos_cluster]

  provisioner "local-exec" {
    command = "scp -i ~/.ssh/${local.ssh_key_name} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null  root@${metal_device.control_plane.0.access_public_ipv4}:/root/baremetal/bmctl-workspace/${local.cluster_name}/${local.cluster_name}-kubeconfig ."
  }
}

data "template_file" "template_kube_vip_install" {
  count    = var.ha_control_plane ? 2 : 1
  template = file("${path.module}/templates/kube_vip_install.sh")
  vars = {
    cluster_name = local.cluster_name
    eip          = cidrhost(metal_reserved_ip_block.cp_vip.cidr_notation, 0)
    count        = count.index
    kube_vip_ver = var.kube_vip_version
    auth_token   = var.metal_auth_token
    project_id   = local.metal_project_id
  }
}

resource "null_resource" "kube_vip_install_first_cp" {
  depends_on = [
    metal_bgp_session.enable_cp_bgp,
    metal_bgp_session.enable_worker_bgp,
    null_resource.prep_anthos_cluster,
  ]
  connection {
    type        = "ssh"
    user        = "root"
    private_key = chomp(tls_private_key.ssh_key_pair.private_key_pem)
    host        = metal_device.control_plane.0.access_public_ipv4
  }
  provisioner "file" {
    content     = data.template_file.template_kube_vip_install.0.rendered
    destination = "/root/bootstrap/kube_vip_install.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "bash /root/bootstrap/kube_vip_install.sh"
    ]
  }
}

data "template_file" "add_remaining_cps" {
  count    = var.ha_control_plane ? 1 : 0
  template = file("${path.module}/templates/add_remaining_cps.sh")
  vars = {
    cluster_name = local.cluster_name
    cp_ip_2      = metal_device.control_plane.1.access_private_ipv4
    cp_id_2      = metal_device.control_plane.1.id
    cp_ip_3      = metal_device.control_plane.2.access_private_ipv4
    cp_id_3      = metal_device.control_plane.2.id
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
    host        = metal_device.control_plane.0.access_public_ipv4
  }
  provisioner "file" {
    content     = data.template_file.add_remaining_cps.0.rendered
    destination = "/root/bootstrap/add_remaining_cps.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "bash /root/bootstrap/add_remaining_cps.sh"
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
    host        = element(metal_device.control_plane.*.access_public_ipv4, count.index + 1)
  }
  provisioner "remote-exec" {
    inline = ["mkdir -p /root/bootstrap"]
  }
  provisioner "file" {
    content     = data.template_file.template_kube_vip_install.1.rendered
    destination = "/root/bootstrap/kube_vip_install.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "bash /root/bootstrap/kube_vip_install.sh"
    ]
  }
}

data "template_file" "ccm_secret" {
  template = file("${path.module}/templates/ccm_secret.yaml")
  vars = {
    auth_token = var.metal_auth_token
    project_id = local.metal_project_id
  }
}

resource "null_resource" "install_ccm" {
  depends_on = [
    null_resource.kube_vip_install_remaining_cp,
    null_resource.deploy_anthos_cluster,
    null_resource.kube_vip_install_first_cp
  ]
  connection {
    type        = "ssh"
    user        = "root"
    private_key = chomp(tls_private_key.ssh_key_pair.private_key_pem)
    host        = metal_device.control_plane.0.access_public_ipv4
  }
  provisioner "file" {
    content     = data.template_file.ccm_secret.rendered
    destination = "/root/bootstrap/ccm_secret.yaml"
  }
  provisioner "remote-exec" {
    inline = [
      "kubectl --kubeconfig /root/baremetal/bmctl-workspace/${local.cluster_name}/${local.cluster_name}-kubeconfig apply -f /root/bootstrap/ccm_secret.yaml",
      "kubectl --kubeconfig /root/baremetal/bmctl-workspace/${local.cluster_name}/${local.cluster_name}-kubeconfig apply -f ${local.ccm_deploy_url}"
    ]
  }
}

data "template_file" "kube_vip_ds" {
  template = file("${path.module}/templates/kube_vip_ds.yaml")
  vars = {
    kube_vip_ver = var.kube_vip_version
  }
}

resource "null_resource" "install_kube_vip_daemonset" {
  depends_on = [
    null_resource.install_ccm
  ]
  connection {
    type        = "ssh"
    user        = "root"
    private_key = chomp(tls_private_key.ssh_key_pair.private_key_pem)
    host        = metal_device.control_plane.0.access_public_ipv4
  }
  provisioner "file" {
    content     = data.template_file.kube_vip_ds.rendered
    destination = "/root/bootstrap/kube_vip_ds.yaml"
  }
  provisioner "remote-exec" {
    inline = [
      "kubectl --kubeconfig /root/baremetal/bmctl-workspace/${local.cluster_name}/${local.cluster_name}-kubeconfig apply -f /root/bootstrap/kube_vip_ds.yaml"
    ]
  }
}

resource "null_resource" "worker_pre_reqs" {
  count = var.worker_count
  depends_on = [
    null_resource.deploy_anthos_cluster,
  ]

  connection {
    type        = "ssh"
    user        = "root"
    private_key = chomp(tls_private_key.ssh_key_pair.private_key_pem)
    host        = element(metal_device.worker_nodes.*.access_public_ipv4, count.index)
  }

  provisioner "remote-exec" {
    inline = ["mkdir -p /root/bootstrap/"]
  }

  provisioner "file" {
    content     = data.template_file.pre_reqs_worker.rendered
    destination = "/root/bootstrap/pre_reqs_worker.sh"
  }

  provisioner "remote-exec" {
    inline = ["bash /root/bootstrap/pre_reqs_worker.sh"]
  }
}

module "storage" {
  source = "./modules/storage"

  depends_on = [
    null_resource.install_ccm,
  ]

  ssh = {
    host             = metal_device.control_plane.0.access_public_ipv4
    private_key      = chomp(tls_private_key.ssh_key_pair.private_key_pem)
    user             = "root"
    kubeconfig       = "/root/baremetal/bmctl-workspace/${local.cluster_name}/${local.cluster_name}-kubeconfig"
    worker_addresses = metal_device.worker_nodes.*.access_public_ipv4
  }

  cluster_name    = local.cluster_name
  storage_module  = var.storage_module
  storage_options = var.storage_options
}
