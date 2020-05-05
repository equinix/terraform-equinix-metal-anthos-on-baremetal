provider "packet" {
    auth_token = var.auth_token
}

resource "packet_vlan" "private_vlan" {
    facility    = var.facility
    project_id  = var.project_id
    description = "Private Network"
}

data "template_file" "user_data" {
    count = var.node_count
    template = file("templates/user_data.sh")
    vars = {
        operating_system = var.operating_system
        ip_address = cidrhost(var.private_subnet, count.index + 1)
        netmask = cidrnetmask(var.private_subnet)
    }
}

resource "packet_device" "baremetal_anthos" {
    count            = var.node_count
    hostname         = format("%s-%02d", var.hostname, count.index + 1)
    plan             = var.plan
    facilities       = [var.facility]
    operating_system = var.operating_system
    billing_cycle    = var.billing_cycle
    project_id       = var.project_id
    network_type     = "hybrid"
    tags             = ["anthos", "baremetal", cidrhost(var.private_subnet, count.index + 1)]
    user_data        = element(data.template_file.user_data.*.rendered, count.index)
}

resource "packet_port_vlan_attachment" "vlan_attach" {
    count = var.node_count
    device_id = element(packet_device.baremetal_anthos.*.id, count.index)
    port_name = "eth1"
    vlan_vnid = packet_vlan.private_vlan.vxlan
}
