variable "auth_token" {
    type = string
    description = "Packet API Key"
}

variable "project_id" {
    type = string
    description = "Packet Project ID"
}

variable "hostname" {
    type = string
    default = "anthos-baremetal"
    description = "Hostname for the nodes"
}

variable "facility" {
    type = string
    default = "sjc1"
    description = "Packet Facility to deploy into"
}

variable "plan" {
    type = string
    default = "c2.medium.x86"
    description = "Packet device type to deploy"
}

variable "node_count" {
    type = number
    description = "Number of baremetal nodes"
    default = 2
}

variable "operating_system" {
    type = string
    description = "The Operating system of the node"
    default = "ubuntu_18_04"
}

variable "billing_cycle" {
    type = string
    description = "How the node will be billed (Not usually changed)"
    default = "hourly"
}

variable "private_subnet" {
    type = string
    description = "Private IP Space to use for Layer2"
    default = "192.168.1.0/24"
}
