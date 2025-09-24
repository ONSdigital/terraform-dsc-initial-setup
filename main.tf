#######################
# Module requirements #
#######################
terraform {
  required_version = ">=1.11.0, <2.0.0"
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
locals {
  activate_apis = distinct(concat(
    [
      "cloudbuild.googleapis.com",
      "cloudresourcemanager.googleapis.com",
      "iam.googleapis.com",
      "storage.googleapis.com",
    ],
    var.additional_apis_services
  ))
}
module "project-services" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = "~> 18.0.0"

  project_id = var.project_id

  activate_apis               = local.activate_apis
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
  source       = "terraform-google-modules/service-accounts/google"
  version      = "~> 4.0"
  project_id   = var.project_id
  names        = ["tf-cloud-build"]
  descriptions = ["Terraform Cloud Build Service Account"]
  project_roles = [
    for role in local.tf_cloud_build_sa_roles : "${var.project_id}=>${role}" # assign roles to the same project
  ]

  depends_on = [module.project-services]
}

##################
# tf gcs buckets #
##################
locals {
  tf_buckets_suffixes = [
    "state-remote-backend", # for terraform remote state storage
    "logs",                 # for storing terraform logs
    "plans",                # for storing terraform plan outputs
    "cloudbuild",           # for storing cloud build artifacts
  ]
  # set no lifecycle rules for the state bucket, this is done through versioning
  # must be separate local as an empty set object causes the module to error
  tf_buckets_lifecycle_rules = {
    "logs"       = [{ action = { type = "Delete" }, condition = { age = 365 } }]
    "plans"      = [{ action = { type = "Delete" }, condition = { age = 90 } }]
    "cloudbuild" = [{ action = { type = "Delete" }, condition = { age = 90 } }]
  }
}
# create all the gcs buckets required for terraform in the gcs project
# https://registry.terraform.io/modules/terraform-google-modules/cloud-storage/google/latest
module "tf-gcs-buckets" {
  source  = "terraform-google-modules/cloud-storage/google"
  version = "~> 11.0"

  # buckets configuration parameters
  project_id               = var.project_id
  location                 = var.region
  public_access_prevention = "enforced" # not negotiable for security - enforce public access prevention
  storage_class            = "STANDARD"
  prefix                   = "${var.project_id}-${var.project_env}-tf"
  names                    = local.tf_buckets_suffixes
  randomize_suffix         = true # enable random suffix for bucket names
  labels                   = local.module_labels

  # set a consistent force_destroy policy and disable adhoc ACLs for all terraform buckets
  force_destroy = {
    for suffix in local.tf_buckets_suffixes : suffix => var.tf_bucket_force_destroy
  }
  bucket_policy_only = {
    for suffix in local.tf_buckets_suffixes : suffix => true
  }

  # enable versioning only for the state-remote-backend bucket (as a recovery mechanism)
  versioning = {
    for suffix in local.tf_buckets_suffixes : suffix => strcontains(suffix, "state-remote-backend")
  }

  # set autoclass to true for all buckets except the state-remote-backend bucket (help minimise costs over time)
  autoclass = {
    for suffix in local.tf_buckets_suffixes : suffix => !strcontains(suffix, "state-remote-backend")
  }

  # add lifecycle rules as defined in the local (control storage costs and data retention)
  bucket_lifecycle_rules = local.tf_buckets_lifecycle_rules

  depends_on = [module.project-services, module.tf-service-account] # random_id.tf-state-remote-backend
}

# set IAM policies for the tf gcs buckets
locals {
  gcs_object_users = distinct(concat([
    "serviceAccount:${module.tf-service-account.email}",
    var.gcs_object_users,
  ]))
} 
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/iam_policy
data "google_iam_policy" "tf-gcs-buckets" {
  binding {
    role    = "roles/storage.admin"
    members = [
      "group:${var.admins_owners_group_email}", # allow the admins/owners group to administer the tf buckets
    ]
  }
  binding {
    role = "roles/storage.objectUser"
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
