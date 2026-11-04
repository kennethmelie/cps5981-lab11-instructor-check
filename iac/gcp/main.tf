# Cougar Advising - Google Cloud declaration (SCANNED ONLY. Never apply this: the lab needs no cloud account.)
# The same system as ../aws/main.tf, built from Google Cloud's equivalent features.
terraform {
  required_providers {
    google = { source = "hashicorp/google", version = "~> 6.0" }
  }
}

provider "google" {
  project = "cougar-advising"
  region  = "us-east1"
}

# Nightly exports of advising ledgers (student financial data).
resource "google_storage_bucket" "exports" {
  name                        = "cougar-advising-exports"
  location                    = "US"
  uniform_bucket_level_access = false
  public_access_prevention    = "inherited"
}

resource "google_storage_bucket_iam_member" "exports_public" {
  bucket = google_storage_bucket.exports.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# Deploy identity used by the CI/CD pipeline (GitHub Actions OIDC via Workload Identity Federation).
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
  }
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "deploy" {
  account_id   = "cougar-deploy"
  display_name = "Cougar deploy pipeline"
}

resource "google_project_iam_member" "deploy_owner" {
  project = "cougar-advising"
  role    = "roles/owner"
  member  = "serviceAccount:${google_service_account.deploy.email}"
}

# Network rule for the advising server.
resource "google_compute_firewall" "ssh" {
  name          = "cougar-ssh"
  network       = "default"
  source_ranges = ["0.0.0.0/0"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_instance" "web" {
  name         = "cougar-web"
  machine_type = "e2-micro"
  zone         = "us-east1-b"
  boot_disk {
    initialize_params { image = "debian-cloud/debian-12" }
  }
  network_interface {
    network = "default"
    access_config {}
  }
  metadata = {
    serial-port-enable = "true"
    startup-script     = "export LEDGER_DB_PASSWORD=cougar2026"
  }
}

# Audit trail of data access (Cloud Audit Logs).
resource "google_project_iam_audit_config" "storage" {
  project = "cougar-advising"
  service = "storage.googleapis.com"
  audit_log_config {
    log_type = "ADMIN_READ"
  }
}
