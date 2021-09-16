locals {
  enabled_apis = [
    "anthos.googleapis.com",
    "anthosaudit.googleapis.com",
    "anthosgke.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "container.googleapis.com",
    "gkeconnect.googleapis.com",
    "gkehub.googleapis.com",
    "iam.googleapis.com",
    "opsconfigmonitoring.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "serviceusage.googleapis.com",
    "stackdriver.googleapis.com"
  ]
}

resource "google_project_service" "enabled-apis" {
  for_each           = toset(local.enabled_apis)
  service            = each.value
  disable_on_destroy = false
}
