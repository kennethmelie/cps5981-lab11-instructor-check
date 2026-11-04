# Cougar Advising - Google Cloud declaration, REMEDIATED (scanned only; never applied in the lab).
terraform {
  required_providers {
    google = { source = "hashicorp/google", version = "~> 6.0" }
  }
}

provider "google" {
  project = "cougar-advising"
  region  = "us-east1"
}

# Nightly exports of advising ledgers (student financial data). Private, versioned, uniform access.
resource "google_storage_bucket" "exports" {
  name                        = "cougar-advising-exports"
  location                    = "US"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  versioning {
    enabled = true
  }
}

# Deploy identity for the pipeline: only this repository's main branch may use the pool.
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }
  attribute_condition = "assertion.sub == 'repo:your-github-username/cps5981-lab11:ref:refs/heads/main'"
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "deploy" {
  account_id   = "cougar-deploy"
  display_name = "Cougar deploy pipeline"
}

resource "google_service_account_iam_member" "deploy_wif" {
  service_account_id = google_service_account.deploy.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/your-github-username/cps5981-lab11"
}

# Least privilege: object write on one bucket, not Owner of the project.
resource "google_storage_bucket_iam_member" "deploy_writer" {
  bucket = google_storage_bucket.exports.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.deploy.email}"
}

# SSH only through Identity-Aware Proxy's address range, which is authenticated and logged.
resource "google_compute_firewall" "ssh" {
  name          = "cougar-ssh-iap"
  network       = "default"
  source_ranges = ["35.235.240.0/20"]
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
  }
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
  metadata = {
    serial-port-enable     = "false"
    block-project-ssh-keys = "true"
    startup-script         = "export LEDGER_DB_PASSWORD_SECRET=projects/cougar-advising/secrets/ledger-db-password"
  }
}

# Audit trail of data access (Cloud Audit Logs): admin reads, data reads and data writes.
resource "google_project_iam_audit_config" "storage" {
  project = "cougar-advising"
  service = "storage.googleapis.com"
  audit_log_config {
    log_type = "ADMIN_READ"
  }
  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}
