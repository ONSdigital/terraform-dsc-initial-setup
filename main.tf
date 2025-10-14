#######################
# Module requirements #
#######################
terraform {
  required_version = ">=1.13.3, <2.0.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">=6.45.0, <7.0.0"
    }
  }
}

locals {
  # add bespoke labels to clarify these resources are managed by this module and are terraformed
  module_labels = {
    "terraform-managed" = "true"
    "terraform-module"  = "terraform-dsc-initial-setup"
  }
}

#####################
# APIs and Services #
#####################
# https://registry.terraform.io/modules/terraform-google-modules/project-factory/google/latest/submodules/project_services
module "project-services" {
  source = "github.com/terraform-google-modules/terraform-google-project-factory//modules/project_services?ref=97a03f2bf4bf1972e12467bc90850e53b6730d8f"

  project_id = var.project_id

  activate_apis = distinct(concat([
    "cloudbuild.googleapis.com",
    "cloudkms.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "storage.googleapis.com"
  ], var.additional_api_services))

  disable_services_on_destroy = var.disable_services_on_destroy
  disable_dependent_services  = var.disable_dependent_services
}

#######
# IAM #
#######
# terraform cloud build service account
locals {
  tf_cloud_build_sa_roles = distinct(concat(
    [
      "roles/cloudbuild.builds.builder",
      "roles/logging.logWriter",
      "roles/serviceusage.serviceUsageConsumer",
    ],
    var.additional_tf_cloud_build_sa_roles
  ))
}
# https://registry.terraform.io/modules/terraform-google-modules/service-accounts/google/latest
module "tf-service-account" {
  source       = "github.com/terraform-google-modules/terraform-google-service-accounts?ref=ed725dc9471efb263528014bf567149a89f97c0a"
  project_id   = var.project_id
  names        = ["tf-cloud-build"]
  descriptions = ["Terraform Cloud Build Service Account"]
  project_roles = [
    for role in local.tf_cloud_build_sa_roles : "${var.project_id}=>${role}"
  ]

  depends_on = [module.project-services]
}

# Grant KMS CryptoKey Encrypter/Decrypter to the GCS service agent
data "google_project" "project" {
  project_id = var.project_id
}

resource "google_kms_crypto_key_iam_member" "gcs_service_agent" {
  crypto_key_id = google_kms_crypto_key.tf-kms-crypto-key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.project.number}@gs-project-accounts.iam.gserviceaccount.com"
}

###################
# Encryption Keys #
###################

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_key_ring
resource "google_kms_key_ring" "tf-kms-key-ring" {
  name     = "tf-key-ring"
  location = var.region
  project  = var.project_id
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key
resource "google_kms_crypto_key" "tf-kms-crypto-key" {
  name            = "tf-crypto-key"
  key_ring        = google_kms_key_ring.tf-kms-key-ring.id
  purpose         = "ENCRYPT_DECRYPT"
  rotation_period = var.kms_key_rotation_period

  lifecycle {
    prevent_destroy = true
  }

  labels     = local.module_labels
  depends_on = [module.project-services]
}


###############
# GCS Buckets #
###############
locals {
  tf_buckets_suffixes = [
    "state",      # for terraform remote state storage
    "plans",      # for storing terraform plan outputs
    "cloudbuild", # for storing cloud build artifacts
  ]
  # set no lifecycle rules for the state bucket, this is done through versioning
  # must be separate local as an empty set object causes the module to error
  tf_buckets_lifecycle_rules = {
    "plans"      = [{ action = { type = "Delete" }, condition = { age = 90 } }]
    "cloudbuild" = [{ action = { type = "Delete" }, condition = { age = 90 } }]
  }
  tf_encryption_key_names = {
    for suffix in local.tf_buckets_suffixes :
    suffix => "projects/${var.project_id}/locations/${var.region}/keyRings/tf-key-ring/cryptoKeys/tf-crypto-key"
  }
}

module "log-bucket" {

  source = "github.com/terraform-google-modules/terraform-google-cloud-storage//modules/simple_bucket?ref=ed8f431fc6ab9c686f89d409f1e02034f245f08f"

  project_id               = var.project_id
  location                 = var.region
  public_access_prevention = "enforced" # not negotiable for security - enforce public access prevention
  name                     = "${var.project_id}-tf-logs"
  labels                   = local.module_labels
  force_destroy            = var.tf_bucket_force_destroy
  bucket_policy_only       = true
  encryption = {
    default_kms_key_name = "projects/${var.project_id}/locations/${var.region}/keyRings/tf-key-ring/cryptoKeys/tf-crypto-key"
  }
  versioning      = true
  autoclass       = true
  lifecycle_rules = [{ action = { type = "Delete" }, condition = { age = 365 } }]

  depends_on = [module.project-services, module.tf-service-account]
}


# https://registry.terraform.io/modules/terraform-google-modules/cloud-storage/google/latest
module "tf-gcs-buckets" {
  source = "github.com/terraform-google-modules/terraform-google-cloud-storage?ref=54d84a43109e42c13383cf98bf1c75d3813ef7fd"

  # buckets configuration parameters
  project_id               = var.project_id
  location                 = var.region
  public_access_prevention = "enforced" # not negotiable for security - enforce public access prevention
  prefix                   = "${var.project_id}-tf"
  names                    = local.tf_buckets_suffixes
  labels                   = local.module_labels

  # set a consistent force_destroy policy and disable adhoc ACLs for all terraform buckets
  force_destroy = {
    for suffix in local.tf_buckets_suffixes : suffix => var.tf_bucket_force_destroy
  }
  bucket_policy_only = {
    for suffix in local.tf_buckets_suffixes : suffix => true
  }

  # set encryption keys for all buckets
  encryption_key_names = local.tf_encryption_key_names

  versioning = {
    for suffix in local.tf_buckets_suffixes : suffix => true
  }

  # set autoclass to true for all buckets except the state-remote-backend bucket (help minimise costs over time)
  autoclass = {
    for suffix in local.tf_buckets_suffixes : suffix => !strcontains(suffix, "state-remote-backend")
  }

  # add lifecycle rules as defined in the local (control storage costs and data retention)
  bucket_lifecycle_rules = local.tf_buckets_lifecycle_rules

  logging = {
    for suffix in local.tf_buckets_suffixes : suffix => {
      log_bucket = module.log-bucket.name
    }
  }

  depends_on = [module.project-services, module.tf-service-account, module.log-bucket, google_kms_crypto_key.tf-kms-crypto-key]
}

# set IAM policies for the tf gcs buckets
locals {
  gcs_object_users = distinct(concat([
    "serviceAccount:${module.tf-service-account.email}"],
    var.gcs_object_users,
  ))
}
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/iam_policy
data "google_iam_policy" "tf-gcs-buckets" {
  binding {
    role = "roles/storage.admin"
    members = compact([
      "group:${var.storage_admins_group_email}",
      "serviceAccount:${module.tf-service-account.email}",
      var.ci_service_account_email != "" ? "serviceAccount:${var.ci_service_account_email}" : "",
    ])
  }
  binding {
    role    = "roles/storage.objectUser"
    members = [for user in local.gcs_object_users : user]
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam.html
resource "google_storage_bucket_iam_policy" "tf-gcs-buckets" {
  for_each    = { for suffix in local.tf_buckets_suffixes : suffix => suffix }
  bucket      = module.tf-gcs-buckets.names[each.key]
  policy_data = data.google_iam_policy.tf-gcs-buckets.policy_data

  depends_on = [module.tf-gcs-buckets]
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/iam_policy
data "google_iam_policy" "log-bucket" {
  binding {
    role = "roles/storage.admin"
    members = compact([
      "group:${var.storage_admins_group_email}",
      "serviceAccount:${module.tf-service-account.email}",
      var.ci_service_account_email != "" ? "serviceAccount:${var.ci_service_account_email}" : "",
    ])
  }
  binding {
    role    = "roles/storage.objectUser"
    members = [for user in local.gcs_object_users : user]
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam.html
resource "google_storage_bucket_iam_policy" "log-bucket" {
  bucket      = module.log-bucket.name
  policy_data = data.google_iam_policy.log-bucket.policy_data
  depends_on  = [module.log-bucket]
}



resource "google_service_account_iam_member" "ci-can-impersonate-setup-sa" {
  count              = var.ci_service_account_email != null && var.ci_service_account_email != "" ? 1 : 0
  service_account_id = "projects/${var.project_id}/serviceAccounts/${module.tf-service-account.email}"
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${var.ci_service_account_email}"
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/logging_project_sink#argument-reference
resource "google_logging_project_sink" "logs-sink" {
  name        = "all-logs-to-bucket"
  project     = var.project_id
  destination = "storage.googleapis.com/${module.log-bucket.name}"
  disabled    = var.disable_logging_sink
  depends_on  = [module.project-services, module.log-bucket]
}

###############
# Monitoring #
###############

locals {
  enable_monitoring_and_alerting = (
    var.environment == "prod" ||
    var.environment == "staging" ||
    var.force_enable_monitoring
  )
}
locals {
  logging_metrics = {
    gcs_iam_change = {
      description     = <<-EOT
        Detects SetIamPolicy changes on GCS buckets.
        Lets us know if someone changes who can access or manage files in our cloud storage.
      EOT
      documentation   = <<-EOT
        This metric tracks changes to IAM policies on GCS buckets, which could indicate changes in access or management permissions for cloud storage.
      EOT
      duration        = "60s"
      threshold_value = 1
      filter          = <<-EOT
        resource.type="gcs_bucket" AND
        protoPayload.methodName="SetIamPolicy"
      EOT
    }
    custom_role_change = {
      description     = <<-EOT
        Detects creation, deletion, or update of custom IAM roles.
        Lets us know if someone creates, deletes, or changes a custom role (a set of permissions) in our project.
      EOT
      documentation   = <<-EOT
        This metric tracks when custom IAM roles are created, deleted, or updated, which may affect project permissions and security boundaries.
      EOT
      duration        = "60s"
      threshold_value = 1
      filter          = <<-EOT
        protoPayload.methodName:("google.iam.admin.v1.CreateRole" OR "google.iam.admin.v1.DeleteRole" OR "google.iam.admin.v1.UpdateRole")
      EOT
    }
    vpc_firewall_change = {
      description     = <<-EOT
        Detects insert, update, or delete of VPC firewall rules.
        Lets us know if someone adds, removes, or changes a rule that controls network traffic in our project.
      EOT
      documentation   = <<-EOT
        This metric tracks changes to VPC firewall rules, which control allowed and denied network traffic in the project.
      EOT
      duration        = "60s"
      threshold_value = 1
      filter          = <<-EOT
        protoPayload.methodName:("compute.firewalls.insert" OR "compute.firewalls.update" OR "compute.firewalls.delete")
      EOT
    }
    vpc_network_change = {
      description     = <<-EOT
        Detects insert, update, or delete of VPC networks.
        Lets us know if someone creates, deletes, or changes a network in our project.
      EOT
      documentation   = <<-EOT
        This metric tracks changes to VPC networks, which may impact connectivity and segmentation in the cloud environment.
      EOT
      duration        = "60s"
      threshold_value = 1
      filter          = <<-EOT
        protoPayload.methodName:("compute.networks.insert" OR "compute.networks.update" OR "compute.networks.delete")
      EOT
    }
    project_ownership_change = {
      description     = <<-EOT
        Detects SetIamPolicy changes that affect project owner bindings.
        Lets us know if someone changes who owns or has full control of the project.
      EOT
      documentation   = <<-EOT
        This metric tracks changes to project owner bindings, which could indicate a transfer of full control or ownership of the project.
      EOT
      duration        = "60s"
      threshold_value = 1
      filter          = <<-EOT
        protoPayload.methodName="SetIamPolicy" AND
        protoPayload.serviceData.policyDelta.bindingDeltas.member:owner
      EOT
    }
    vpc_route_change = {
      description     = <<-EOT
        Detects insert, update, or delete of VPC network routes.
        Lets us know if someone changes how network traffic is routed in our project.
      EOT
      documentation   = <<-EOT
        This metric tracks changes to VPC network routes, which determine how network traffic is directed within the project.
      EOT
      duration        = "60s"
      threshold_value = 1
      filter          = <<-EOT
        protoPayload.methodName:("compute.routes.insert" OR "compute.routes.update" OR "compute.routes.delete")
      EOT
    }
  }
}

resource "google_logging_metric" "security_metrics" {
  for_each    = local.enable_monitoring_and_alerting ? local.logging_metrics : {}
  project     = var.project_id
  name        = each.key
  description = each.value.description
  filter      = each.value.filter
  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
  }
}

resource "google_monitoring_alert_policy" "security_alerts" {
  for_each     = local.enable_monitoring_and_alerting ? local.logging_metrics : {}
  project      = var.project_id
  display_name = "Security Alerts"
  combiner     = "OR"

  dynamic "conditions" {
    for_each = local.logging_metrics
    content {
      display_name = "Alert on ${conditions.key}"
      condition_threshold {
        filter          = "metric.type=\"logging.googleapis.com/user/${conditions.key}\""
        duration        = conditions.value.duration
        comparison      = "COMPARISON_GT"
        threshold_value = conditions.value.threshold_value
        aggregations {
          alignment_period     = "60s"
          per_series_aligner   = "ALIGN_DELTA"
          cross_series_reducer = "REDUCE_SUM"
          group_by_fields      = []
        }
      }
    }
  }

  notification_channels = var.monitoring_notification_channel_ids

  documentation {
    content   = trimspace(local.logging_metrics[each.key].documentation)
    mime_type = "text/markdown"
  }

  user_labels = local.module_labels
  depends_on  = [google_logging_metric.security_metrics]
}
