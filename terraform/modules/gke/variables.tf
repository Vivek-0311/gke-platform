variable "project_id" {
  type = string
}

variable "name" {
  description = "Cluster name."
  type        = string
}

variable "location" {
  description = "Zone (cheaper, one free zonal cluster per billing account) or region (HA control plane)."
  type        = string
}

variable "network_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "pods_range_name" {
  type = string
}

variable "services_range_name" {
  type = string
}

variable "master_cidr" {
  description = "/28 range for the control plane's private endpoint."
  type        = string
  default     = "172.16.0.0/28"
}

variable "authorized_networks" {
  description = "Optional CIDRs allowed to reach the IP-based control plane endpoint. CI uses the DNS endpoint instead."
  type = list(object({
    name = string
    cidr = string
  }))
  default = []
}

variable "release_channel" {
  type    = string
  default = "REGULAR"
}

variable "machine_type" {
  type    = string
  default = "e2-standard-2"
}

variable "spot" {
  description = "Use Spot VMs for the node pool (much cheaper, fine for demos)."
  type        = bool
  default     = true
}

variable "min_nodes" {
  type    = number
  default = 1
}

variable "max_nodes" {
  type    = number
  default = 3
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "labels" {
  type    = map(string)
  default = {}
}
