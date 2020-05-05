output "Hostnames" {
    value = packet_device.baremetal_anthos.*.hostname
    description = "Node hostnames"
}

output "Public_IPs" {
    value = packet_device.baremetal_anthos.*.access_public_ipv4
    description = "Node Public IPs"
}

output "Tags" {
    value = packet_device.baremetal_anthos.*.tags
    description = "Tags"
}
