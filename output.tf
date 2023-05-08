output "Control_Plane_Public_IPs" {
  value       = equinix_metal_device.control_plane.*.access_public_ipv4
  description = "Control Plane Public IPs"
}

output "Worker_Public_IPs" {
  value       = equinix_metal_device.worker_nodes.*.access_public_ipv4
  description = "Worker Node Public IPs"
}

output "ssh_key_location" {
  value       = local_file.cluster_private_key_pem.filename
  description = "The SSH Private Key File Location"
}

output "Control_Plane_VIP" {
  value       = cidrhost(equinix_metal_reserved_ip_block.cp_vip.cidr_notation, 0)
  description = "The Virtual IP for the Control Plane"
}

output "Ingress_VIP" {
  value       = cidrhost(equinix_metal_reserved_ip_block.ingress_vip.cidr_notation, 0)
  description = "The Virtual IP for Ingress"
}

output "Kubeconfig_location" {
  value       = format("%s/%s-kubeconfig", abspath(path.root), local.cluster_name)
  description = "The path to your kubeconfig"
}

output "Equinix_Metal_Project_ID" {
  value       = local.metal_project_id
  description = "The Metal project ID used for this deployment"
}
