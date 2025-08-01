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
resource "google_secret_manager_secret" "tfvars_secrets" {
  secret_id = var.tfvars_secret_id
  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
  version_destroy_ttl = var.tfvars_secret_version_delete_ttl

  depends_on = [module.project-services]
}
