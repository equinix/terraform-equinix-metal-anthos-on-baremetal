provider "equinix" {
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

resource "equinix_metal_project" "new_project" {
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
  metal_project_id    = var.metal_create_project ? equinix_metal_project.new_project[0].id : var.metal_project_id
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

resource "equinix_metal_ssh_key" "ssh_pub_key" {
  name       = local.cluster_name
  public_key = chomp(tls_private_key.ssh_key_pair.public_key_openssh)
}

resource "local_file" "cluster_private_key_pem" {
  content         = chomp(tls_private_key.ssh_key_pair.private_key_pem)
  filename        = pathexpand(format("~/.ssh/%s", local.ssh_key_name))
  file_permission = "0600"
}

resource "equinix_metal_reserved_ip_block" "cp_vip" {
  project_id  = local.metal_project_id
  metro       = var.metro
  quantity    = 1
  description = format("Cluster: '%s' Contol Plane VIP", local.cluster_name)
}

resource "equinix_metal_reserved_ip_block" "ingress_vip" {
  project_id  = local.metal_project_id
  metro       = var.metro
  quantity    = 1
  description = format("Cluster: '%s' Ingress VIP", local.cluster_name)
}

data "cloudinit_config" "cp_user_data" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/templates/user_data.sh", {
      operating_system = var.operating_system
    })
  }

  part {
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/templates/cp-cloud-config.yaml", {
      ssh_key          = chomp(tls_private_key.ssh_key_pair.private_key_pem)
      gcr_sa_key       = local.gcr_sa_key
      connect_sa_key   = local.connect_sa_key
      register_sa_key  = local.register_sa_key
      cloud_ops_sa_key = local.cloud_ops_sa_key
      bmctl_sa_key     = local.bmctl_sa_key

      create_cluster = templatefile("${path.module}/templates/create_cluster.sh", {
        cluster_name = local.cluster_name
      })

      kube_vip_install = templatefile("${path.module}/templates/kube_vip_install.sh", {
        cluster_name = local.cluster_name
        eip          = cidrhost(equinix_metal_reserved_ip_block.cp_vip.cidr_notation, 0)
        count        = 0
        kube_vip_ver = var.kube_vip_version
        auth_token   = var.metal_auth_token
        project_id   = local.metal_project_id
      })

      ccm_secret = templatefile("${path.module}/templates/ccm_secret.yaml", {
        auth_token = var.metal_auth_token
        project_id = local.metal_project_id
      })
    })
  }
}

data "cloudinit_config" "worker_user_data" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/cloud-config"
    content      = templatefile("${path.module}/templates/cloud-config.yaml", {})
  }
  part {
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/templates/user_data.sh", {
      operating_system = var.operating_system
    })
  }
}


resource "equinix_metal_device" "control_plane" {
  depends_on = [
    equinix_metal_ssh_key.ssh_pub_key
  ]
  count            = local.cp_count
  hostname         = format("%s-cp-%02d", local.cluster_name, count.index + 1)
  plan             = var.cp_plan
  metro            = var.metro
  operating_system = var.operating_system
  billing_cycle    = var.billing_cycle
  project_id       = local.metal_project_id
  user_data        = data.cloudinit_config.cp_user_data.rendered
  tags             = ["anthos", "baremetal", "control-plane"]
}

resource "equinix_metal_device" "worker_nodes" {
  depends_on = [
    equinix_metal_ssh_key.ssh_pub_key
  ]
  count            = var.worker_count
  hostname         = format("%s-worker-%02d", local.cluster_name, count.index + 1)
  plan             = var.worker_plan
  metro            = var.metro
  operating_system = var.operating_system
  billing_cycle    = var.billing_cycle
  project_id       = local.metal_project_id
  user_data        = data.cloudinit_config.worker_user_data.rendered
  tags             = ["anthos", "baremetal", "worker"]
}

resource "equinix_metal_bgp_session" "enable_cp_bgp" {
  count          = local.cp_count
  device_id      = element(equinix_metal_device.control_plane.*.id, count.index)
  address_family = "ipv4"
}

resource "equinix_metal_bgp_session" "enable_worker_bgp" {
  count          = var.worker_count
  device_id      = element(equinix_metal_device.worker_nodes.*.id, count.index)
  address_family = "ipv4"
}

resource "null_resource" "prep_anthos_cluster" {
  depends_on = [
    google_project_service.enabled-apis
  ]

  connection {
    type        = "ssh"
    user        = "root"
    private_key = chomp(tls_private_key.ssh_key_pair.private_key_pem)
    host        = equinix_metal_device.control_plane.0.access_public_ipv4
  }


  provisioner "file" {
    content = templatefile("${path.module}/templates/pre_reqs.sh", {
      cluster_name     = local.cluster_name
      operating_system = var.operating_system
      cp_vip           = cidrhost(equinix_metal_reserved_ip_block.cp_vip.cidr_notation, 0)
      ingress_vip      = cidrhost(equinix_metal_reserved_ip_block.ingress_vip.cidr_notation, 0)
      cp_ips           = join(" ", equinix_metal_device.control_plane.*.access_private_ipv4)
      cp_ids           = join(" ", equinix_metal_device.control_plane.*.id)
      worker_ips       = join(" ", equinix_metal_device.worker_nodes.*.access_private_ipv4)
      worker_ids       = join(" ", equinix_metal_device.worker_nodes.*.id)
      anthos_ver       = var.anthos_version
    })
    destination = "/root/bootstrap/pre_reqs.sh"
  }

  provisioner "remote-exec" {
    inline = ["bash /root/bootstrap/pre_reqs.sh"]
  }
}

// Initialize Anthos on the first control plane node.
// This will also trigger installs (including apt)
// on the worker nodes.
resource "null_resource" "deploy_anthos_cluster" {
  depends_on = [
    null_resource.prep_anthos_cluster,
  ]
  connection {
    type        = "ssh"
    user        = "root"
    private_key = chomp(tls_private_key.ssh_key_pair.private_key_pem)
    host        = equinix_metal_device.control_plane.0.access_public_ipv4
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
    command = "scp -i ~/.ssh/${local.ssh_key_name} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null  root@${equinix_metal_device.control_plane.0.access_public_ipv4}:/root/baremetal/bmctl-workspace/${local.cluster_name}/${local.cluster_name}-kubeconfig ."
  }
}

resource "null_resource" "kube_vip_install_first_cp" {
  depends_on = [
    equinix_metal_bgp_session.enable_cp_bgp,
    equinix_metal_bgp_session.enable_worker_bgp,
    null_resource.prep_anthos_cluster,
  ]
  connection {
    type        = "ssh"
    user        = "root"
    private_key = chomp(tls_private_key.ssh_key_pair.private_key_pem)
    host        = equinix_metal_device.control_plane.0.access_public_ipv4
  }
  provisioner "remote-exec" {
    inline = [
      "bash /root/bootstrap/kube_vip_install.sh"
    ]
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
    host        = equinix_metal_device.control_plane.0.access_public_ipv4
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/add_remaining_cps.sh", {
      cluster_name = local.cluster_name
      cp_ip_2      = equinix_metal_device.control_plane.1.access_private_ipv4
      cp_id_2      = equinix_metal_device.control_plane.1.id
      cp_ip_3      = equinix_metal_device.control_plane.2.access_private_ipv4
      cp_id_3      = equinix_metal_device.control_plane.2.id
    })
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
    host        = element(equinix_metal_device.control_plane.*.access_public_ipv4, count.index + 1)
  }
  provisioner "remote-exec" {
    inline = ["mkdir -p /root/bootstrap"]
  }
  provisioner "file" {
    content = templatefile("${path.module}/templates/kube_vip_install.sh", {
      cluster_name = local.cluster_name
      eip          = cidrhost(equinix_metal_reserved_ip_block.cp_vip.cidr_notation, 0)
      count        = 1
      kube_vip_ver = var.kube_vip_version
      auth_token   = var.metal_auth_token
      project_id   = local.metal_project_id
    })

    destination = "/root/bootstrap/kube_vip_install.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "bash /root/bootstrap/kube_vip_install.sh"
    ]
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
    host        = equinix_metal_device.control_plane.0.access_public_ipv4
  }

  provisioner "remote-exec" {
    inline = [
      "kubectl --kubeconfig /root/baremetal/bmctl-workspace/${local.cluster_name}/${local.cluster_name}-kubeconfig apply -f /root/bootstrap/ccm_secret.yaml",
      "kubectl --kubeconfig /root/baremetal/bmctl-workspace/${local.cluster_name}/${local.cluster_name}-kubeconfig apply -f ${local.ccm_deploy_url}"
    ]
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
    host        = equinix_metal_device.control_plane.0.access_public_ipv4
  }
  provisioner "file" {
    content = templatefile("${path.module}/templates/kube_vip_ds.yaml", {
      kube_vip_ver = var.kube_vip_version
    })
    destination = "/root/bootstrap/kube_vip_ds.yaml"
  }
  provisioner "remote-exec" {
    inline = [
      "kubectl --kubeconfig /root/baremetal/bmctl-workspace/${local.cluster_name}/${local.cluster_name}-kubeconfig apply -f /root/bootstrap/kube_vip_ds.yaml"
    ]
  }
}

module "storage" {
  source = "./modules/storage"

  depends_on = [
    null_resource.install_ccm,
  ]

  ssh = {
    host             = equinix_metal_device.control_plane.0.access_public_ipv4
    private_key      = chomp(tls_private_key.ssh_key_pair.private_key_pem)
    user             = "root"
    kubeconfig       = "/root/baremetal/bmctl-workspace/${local.cluster_name}/${local.cluster_name}-kubeconfig"
    worker_addresses = equinix_metal_device.worker_nodes.*.access_public_ipv4
  }

  cluster_name    = local.cluster_name
  storage_module  = var.storage_module
  storage_options = var.storage_options
}
