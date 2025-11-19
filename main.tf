#######################
# Module requirements #
#######################
terraform {
  required_version = ">=1.13.5, <2.0.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">=7.12.0, <8.0.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">=0.13.1, <1.0.0"
    }
  }
}

#####################
# APIs and Services #
#####################
# https://registry.terraform.io/modules/terraform-google-modules/project-factory/google/latest/submodules/project_services
module "project-services" {
  source = "github.com/terraform-google-modules/terraform-google-project-factory//modules/project_services?ref=1227d7045535b263b9dcd332c7cfb1d2a38298d6"

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

resource "time_sleep" "wait_for_apis" {
  count           = var.wait_for_apis ? 1 : 0
  depends_on      = [module.project-services]
  create_duration = var.wait_for_apis_duration
}

module "setup" {
  source     = "./setup"
  depends_on = [time_sleep.wait_for_apis]

  project_id                          = var.project_id
  region                              = var.region
  environment                         = var.environment
  additional_tf_cloud_build_sa_roles  = var.additional_tf_cloud_build_sa_roles
  ci_service_account_email            = var.ci_service_account_email
  storage_admins_group_email          = var.storage_admins_group_email
  gcs_object_users                    = var.gcs_object_users
  tf_bucket_force_destroy             = var.tf_bucket_force_destroy
  kms_key_rotation_period             = var.kms_key_rotation_period
  disable_logging_sink                = var.disable_logging_sink
  force_enable_monitoring             = var.force_enable_monitoring
  monitoring_notification_channel_ids = var.monitoring_notification_channel_ids
}
