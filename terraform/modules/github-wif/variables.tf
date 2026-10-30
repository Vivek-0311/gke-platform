variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "github_repository" {
  description = "GitHub repository allowed to deploy, as owner/name."
  type        = string
}

variable "pool_id" {
  type    = string
  default = "github-actions"
}

variable "deployer_account_id" {
  type    = string
  default = "gh-deployer"
}

variable "artifact_repository_id" {
  description = "Artifact Registry repository the deployer may push to."
  type        = string
}
