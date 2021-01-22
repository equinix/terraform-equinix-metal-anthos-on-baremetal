locals {
  enabled_apis = [
    "anthos.googleapis.com",
    "anthosgke.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "gkeconnect.googleapis.com",
    "serviceusage.googleapis.com",
    "stackdriver.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com"
  ]
}

resource "google_project_service" "enabled-apis" {
  for_each           = toset(local.enabled_apis)
  service            = each.value
  disable_on_destroy = false
}
