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
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">=6.45.0, <7.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.7.2, < 4.0.0"
    }
  }
}

#####################
# APIs and Services #
#####################
# https://registry.terraform.io/modules/terraform-google-modules/project-factory/google/latest/submodules/project_services
# TODO: define the minimum set of APIs required for the startup the project
module "project-services" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = "~> 18.0.0"

  project_id = var.project_id

  activate_apis               = var.apis_services
  disable_services_on_destroy = var.disable_services_on_destroy
  disable_dependent_services  = var.disable_dependent_services
}

#######
# IAM #
#######
# terraform cloud build service account
# https://registry.terraform.io/modules/terraform-google-modules/service-accounts/google/latest
module "tf-service-account" {
  source       = "terraform-google-modules/service-accounts/google"
  version      = "~> 4.0"
  project_id   = var.project_id
  names        = ["tf-cloud-build"]
  descriptions = ["Terraform Cloud Build Service Account"]
  project_roles = [
    for role in var.tf_cloud_build_sa_roles : "${var.project_id}=>${role}" # assign roles to the same project
  ]

  depends_on = [module.project-services]
}

##################
# tfvars secrets #
##################
# no currently available gcp/terraform module for secret manager (auto-push/pull of secrets only)
resource "google_secret_manager_regional_secret" "tfvars-secret" {
  secret_id           = var.tfvars_secret_id
  location            = var.region
  version_destroy_ttl = var.tfvars_secret_version_delete_ttl

  depends_on = [module.project-services]
}

##################
# tf gcs buckets #
##################
# use a random id to create unique bucket names
# https://cloud.google.com/docs/terraform/resource-management/store-state
resource "random_id" "tf-state-remote-backend" {
  byte_length = 8
}
# use a local variable to define the bucket suffixes, including the random id prefix for the state bucket
locals {
  tf_bucket_suffixes = ["${random_id.tf-state-remote-backend.hex}-state-remote-backend", "logs", "plans", "cloudbuild"]
}
# create all the gcs buckets required for terraform in the gcs project
# https://registry.terraform.io/modules/terraform-google-modules/cloud-storage/google/latest
# TODO: define lifcycle rules (including prevent destroying, auto-deletion after X period as needed) and soft delete policies for the tf buckets
module "tf-gcs-buckets" {
  source  = "terraform-google-modules/cloud-storage/google"
  version = "~> 11.0"

  # buckets configuration parameters
  project_id               = var.project_id
  location                 = var.region
  public_access_prevention = true # not negotiable for security - enforce public access prevention
  storage_class            = "STANDARD"
  prefix                   = "${var.project_id}-${var.project_env}-tf-"
  names                    = local.tf_bucket_suffixes

  # object level bindings - controlling access to the tf bucket contents
  admins = ["group:${var.admins_owners_group_email}"]
  creators = [
    "serviceAccount:${module.tf-service-account.email}", # allow the tf cloud build service account to create objects
    "group:${var.cloud_eng_group_email}",                # required for tf state initial set-up + migration TODO: explore this further
  ]
  viewers = [
    "group:${var.cloud_eng_group_email}",                # allow the cloud engineering group to view the tf buckets
    "serviceAccount:${module.tf-service-account.email}", # allow the tf cloud build service account to view objects
  ]

  # enable versioning only for buckets whose suffix contains "state"
  versioning = {
    for suffix in local.tf_bucket_suffixes : suffix => strcontains(suffix, "-state-remote-backend")
  }

  # set a consistent force_destroy policy for all buckets
  force_destroy = {
    for suffix in local.tf_bucket_suffixes : suffix => var.tf_bucket_force_destroy
  }

  # add bespoke labels to clarify these buckets are managed by this module and terraformed
  labels = {
    "terraform-managed" = "true"
    "source"            = "terraform-dsc-initial-setup"
  }

  # disable adhoc ACLs for all buckets
  bucket_policy_only = {
    for suffix in local.tf_bucket_suffixes : suffix => true
  }

  depends_on = [module.project-services, module.tf-service-account, random_id.tf-state-remote-backend]
}
