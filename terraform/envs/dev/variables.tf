variable "project_id" {
  description = "GCP project to deploy into."
  type        = string
}

variable "region" {
  type    = string
  default = "asia-south1"
}

variable "zone" {
  description = "Zonal cluster keeps the dev environment cheap."
  type        = string
  default     = "asia-south1-a"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "machine_type" {
  type    = string
  default = "e2-standard-2"
}

variable "github_repository" {
  description = "Repository allowed to deploy via Workload Identity Federation (owner/name)."
  type        = string
}

variable "app_namespace" {
  type    = string
  default = "demo"
}

variable "greeting" {
  description = "Value stored in Secret Manager and read by the app at startup."
  type        = string
  default     = "Hello from Secret Manager, fetched with Workload Identity!"
  sensitive   = true
}
