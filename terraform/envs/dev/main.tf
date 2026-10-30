locals {
  name = "showcase-${var.environment}"
  labels = {
    project     = "gke-platform-showcase"
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "artifactregistry.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "secretmanager.googleapis.com",
  ])
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

module "network" {
  source     = "../../modules/network"
  project_id = var.project_id
  name       = local.name
  region     = var.region

  depends_on = [google_project_service.apis]
}

module "gke" {
  source              = "../../modules/gke"
  project_id          = var.project_id
  name                = local.name
  location            = var.zone
  network_id          = module.network.network_id
  subnet_id           = module.network.subnet_id
  pods_range_name     = module.network.pods_range_name
  services_range_name = module.network.services_range_name
  machine_type        = var.machine_type
  spot                = true
  min_nodes           = 1
  max_nodes           = 3
  deletion_protection = false # dev: allow `terraform destroy`
  labels              = local.labels
}

module "registry" {
  source     = "../../modules/artifact-registry"
  project_id = var.project_id
  region     = var.region
  name       = "showcase"
  labels     = local.labels

  depends_on = [google_project_service.apis]
}

module "github_wif" {
  source                 = "../../modules/github-wif"
  project_id             = var.project_id
  region                 = var.region
  github_repository      = var.github_repository
  artifact_repository_id = module.registry.repository_id

  depends_on = [google_project_service.apis]
}

# --- Demo app identity: Kubernetes SA -> Google SA via Workload Identity ---

resource "google_service_account" "app" {
  project      = var.project_id
  account_id   = "demo-app"
  display_name = "demo-app workload"
}

resource "google_service_account_iam_member" "app_wi" {
  service_account_id = google_service_account.app.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${module.gke.workload_pool}[${var.app_namespace}/demo-app]"
}

resource "google_secret_manager_secret" "greeting" {
  project   = var.project_id
  secret_id = "demo-app-greeting"
  labels    = local.labels

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "greeting" {
  secret      = google_secret_manager_secret.greeting.id
  secret_data = var.greeting
}

# The app can read this one secret and nothing else.
resource "google_secret_manager_secret_iam_member" "app_reads_greeting" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.greeting.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.app.email}"
}
