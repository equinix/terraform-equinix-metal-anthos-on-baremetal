output "Control_Plane_Public_IPs" {
  value       = packet_device.control_plane.*.access_public_ipv4
  description = "Control Plane Public IPs"
}

output "Worker_Public_IPs" {
  value       = packet_device.worker_nodes.*.access_public_ipv4
  description = "Worker Node Public IPs"
}

output "ssh_key_location" {
  value       = local_file.cluster_private_key_pem.filename
  description = "The SSH Private Key File Location"
}

output "Control_Plane_VIP" {
  value       = cidrhost(packet_reserved_ip_block.cp_vip.cidr_notation, 0)
  description = "The Virtual IP for the Control Plane"
}
output "Ingress_VIP" {
  value       = cidrhost(packet_reserved_ip_block.ingress_vip.cidr_notation, 0)
  description = "The Virtual IP for Ingress"
}
