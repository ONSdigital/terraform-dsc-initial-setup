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

# trivy:ignore:AVD-GCP-0077
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

  # enable versioning only for the state-remote-backend bucket (as a recovery mechanism)
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

resource "google_service_account_iam_member" "ci-can-impersonate-setup-sa" {
  count              = var.ci_service_account_email != null && var.ci_service_account_email != "" ? 1 : 0
  service_account_id = "projects/${var.project_id}/serviceAccounts/${module.tf-service-account.email}"
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${var.ci_service_account_email}"
}
