# Private GKE cluster:
# - nodes have no public IPs (egress through Cloud NAT)
# - control plane reached through the DNS-based endpoint, authorised by IAM
#   (no IP allow-lists to maintain for CI runners)
# - Workload Identity on, Dataplane V2 (built-in NetworkPolicy), Shielded nodes
# - separate, autoscaled node pool with a least-privilege node service account

resource "google_service_account" "nodes" {
  project      = var.project_id
  account_id   = "${var.name}-nodes"
  display_name = "GKE nodes for ${var.name}"
}

locals {
  node_roles = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/artifactregistry.reader",
  ]
}

resource "google_project_iam_member" "nodes" {
  for_each = toset(local.node_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.nodes.email}"
}

resource "google_container_cluster" "this" {
  project  = var.project_id
  name     = var.name
  location = var.location

  network    = var.network_id
  subnetwork = var.subnet_id

  # Manage nodes in a separate pool.
  remove_default_node_pool = true
  initial_node_count       = 1

  deletion_protection = var.deletion_protection
  networking_mode     = "VPC_NATIVE"
  datapath_provider   = "ADVANCED_DATAPATH"

  release_channel {
    channel = var.release_channel
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_cidr
  }

  control_plane_endpoints_config {
    dns_endpoint_config {
      allow_external_traffic = true
    }
  }

  dynamic "master_authorized_networks_config" {
    for_each = length(var.authorized_networks) > 0 ? [1] : []
    content {
      dynamic "cidr_blocks" {
        for_each = var.authorized_networks
        content {
          cidr_block   = cidr_blocks.value.cidr
          display_name = cidr_blocks.value.name
        }
      }
    }
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  enable_shielded_nodes = true

  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }

  maintenance_policy {
    recurring_window {
      start_time = "2025-01-01T20:00:00Z"
      end_time   = "2025-01-02T02:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=SA,SU"
    }
  }

  resource_labels = var.labels
}

resource "google_container_node_pool" "primary" {
  project  = var.project_id
  name     = "${var.name}-primary"
  location = var.location
  cluster  = google_container_cluster.this.id

  autoscaling {
    min_node_count = var.min_nodes
    max_node_count = var.max_nodes
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  node_config {
    machine_type    = var.machine_type
    spot            = var.spot
    disk_size_gb    = 50
    disk_type       = "pd-balanced"
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    labels          = var.labels

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  depends_on = [google_project_iam_member.nodes]
}
