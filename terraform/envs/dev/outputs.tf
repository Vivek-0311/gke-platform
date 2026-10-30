output "cluster_name" {
  value = module.gke.name
}

output "cluster_location" {
  value = module.gke.location
}

output "cluster_dns_endpoint" {
  value = module.gke.dns_endpoint
}

output "image_prefix" {
  value = module.registry.image_prefix
}

output "app_service_account" {
  description = "Put this in helm values: serviceAccount.gcpServiceAccount."
  value       = google_service_account.app.email
}

output "github_variables" {
  description = "Copy these into the GitHub repository's Actions variables."
  value = {
    GCP_PROJECT_ID   = var.project_id
    GCP_REGION       = var.region
    GKE_CLUSTER      = module.gke.name
    GKE_LOCATION     = module.gke.location
    GCP_WIF_PROVIDER = module.github_wif.workload_identity_provider
    GCP_DEPLOYER_SA  = module.github_wif.deployer_service_account
    IMAGE_PREFIX     = module.registry.image_prefix
    APP_GSA          = google_service_account.app.email
  }
}
