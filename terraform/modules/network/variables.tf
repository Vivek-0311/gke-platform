variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "name" {
  description = "Prefix for all network resources."
  type        = string
}

variable "region" {
  description = "Region for the subnet, router and NAT."
  type        = string
}

variable "nodes_cidr" {
  description = "Primary range for GKE nodes."
  type        = string
  default     = "10.10.0.0/20"
}

variable "pods_cidr" {
  description = "Secondary range for pods."
  type        = string
  default     = "10.20.0.0/16"
}

variable "services_cidr" {
  description = "Secondary range for services."
  type        = string
  default     = "10.30.0.0/20"
}
