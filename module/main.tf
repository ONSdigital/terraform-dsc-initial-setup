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
