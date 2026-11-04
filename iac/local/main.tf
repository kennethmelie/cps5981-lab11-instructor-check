# Declared state of the lab target: a single-tenant, local deployment of Cougar Advising.
# Terraform renders it into rendered/; the drift check compares that with deployed/.
terraform {
  required_version = ">= 1.6"
  required_providers {
    local = { source = "hashicorp/local", version = "2.5.2" }
  }
}

locals {
  app_config = {
    listen              = "127.0.0.1:3000"
    debug               = false
    session_ttl_minutes = 30
    ledger_export       = "nightly"
  }
  firewall = {
    default = "deny"
    inbound = [
      { port = 443, from = "campus-vpn", note = "HTTPS for advisors" }
    ]
  }
}

resource "local_file" "app_config" {
  filename = "${path.module}/../../rendered/app-config.json"
  content  = jsonencode(local.app_config)
}

resource "local_file" "firewall" {
  filename = "${path.module}/../../rendered/firewall.json"
  content  = jsonencode(local.firewall)
}
