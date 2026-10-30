# Remote state in GCS (versioned bucket, created once by hand or by `make bootstrap`).
# Pass the bucket at init time so nothing project-specific is committed:
#   terraform init -backend-config="bucket=<your-state-bucket>"
terraform {
  backend "gcs" {
    prefix = "gke-platform-showcase/dev"
  }
}
