locals {
  sa_count          = var.gcp_keys_path == "" ? 1 : 0
  sa_text           = "serviceAccount"
  sa_display_prefix = "Anthos Bare Metal Service Account for"
}

resource "google_service_account" "gcr_sa" {
  count        = local.sa_count
  account_id   = format("%s-gcr", local.cluster_name)
  display_name = format("%s %s GCR", local.sa_display_prefix, local.cluster_name)
}

resource "google_service_account" "connect_sa" {
  count        = local.sa_count
  account_id   = format("%s-connect", local.cluster_name)
  display_name = format("%s %s Connect", local.sa_display_prefix, local.cluster_name)
}

resource "google_service_account" "register_sa" {
  count        = local.sa_count
  account_id   = format("%s-register", local.cluster_name)
  display_name = format("%s %s Register", local.sa_display_prefix, local.cluster_name)
}

resource "google_service_account" "cloud_ops_sa" {
  count        = local.sa_count
  account_id   = format("%s-ops", local.cluster_name)
  display_name = format("%s %s Cloud Ops", local.sa_display_prefix, local.cluster_name)
}

resource "google_service_account" "bmctl_sa" {
  count        = local.sa_count
  account_id   = format("%s-bmctl", local.cluster_name)
  display_name = format("%s %s Installation (bmctl)", local.sa_display_prefix, local.cluster_name)
}

resource "google_project_iam_member" "connect_sa_role_connect" {
  count  = local.sa_count
  role   = "roles/gkehub.connect"
  member = format("%s:%s", local.sa_text, google_service_account.connect_sa[count.index].email)
}

resource "google_project_iam_member" "register_sa_role_admin" {
  count  = local.sa_count
  role   = "roles/gkehub.admin"
  member = format("%s:%s", local.sa_text, google_service_account.register_sa[count.index].email)
}

resource "google_project_iam_member" "cloud_ops_sa_role_logwriter" {
  count  = local.sa_count
  role   = "roles/logging.logWriter"
  member = format("%s:%s", local.sa_text, google_service_account.cloud_ops_sa[count.index].email)
}

resource "google_project_iam_member" "cloud_ops_sa_role_metricwriter" {
  count  = local.sa_count
  role   = "roles/monitoring.metricWriter"
  member = format("%s:%s", local.sa_text, google_service_account.cloud_ops_sa[count.index].email)
}

resource "google_project_iam_member" "cloud_ops_sa_role_resourcewriter" {
  count  = local.sa_count
  role   = "roles/stackdriver.resourceMetadata.writer"
  member = format("%s:%s", local.sa_text, google_service_account.cloud_ops_sa[count.index].email)
}

resource "google_project_iam_member" "cloud_ops_sa_role_dashboard" {
  count  = local.sa_count
  role   = "roles/monitoring.dashboardEditor"
  member = format("%s:%s", local.sa_text, google_service_account.cloud_ops_sa[count.index].email)
}

resource "google_project_iam_member" "cloud_ops_sa_role_metadata_writer" {
  count  = local.sa_count
  role   = "roles/opsconfigmonitoring.resourceMetadata.writer"
  member = format("%s:%s", local.sa_text, google_service_account.cloud_ops_sa[count.index].email)
}


resource "google_project_iam_member" "bmctl_sa_compute" {
  count  = local.sa_count
  role   = "roles/compute.viewer"
  member = format("%s:%s", local.sa_text, google_service_account.bmctl_sa[count.index].email)
}

resource "google_service_account_key" "gcr_sa_key" {
  count              = local.sa_count
  service_account_id = google_service_account.gcr_sa[count.index].name
}

resource "google_service_account_key" "connect_sa_key" {
  count              = local.sa_count
  service_account_id = google_service_account.connect_sa[count.index].name
}

resource "google_service_account_key" "register_sa_key" {
  count              = local.sa_count
  service_account_id = google_service_account.register_sa[count.index].name
}

resource "google_service_account_key" "cloud_ops_sa_key" {
  count              = local.sa_count
  service_account_id = google_service_account.cloud_ops_sa[count.index].name
}

resource "google_service_account_key" "bmctl_sa_key" {
  count              = local.sa_count
  service_account_id = google_service_account.bmctl_sa[count.index].name
}
