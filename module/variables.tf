#########################
# PROJECT CONFIGURATION #
#########################
variable "project_id" {
  description = "The GCP project ID where the services will be activated."
  type        = string
  nullable    = false
}
variable "region" {
  description = "The GCP region where the resources will be created."
  type        = string
  nullable    = false
}

################
# API SERVICES #
################
variable "apis_services" {
  description = "List of APIs/services to be activated in the project, in XXXX.googleapis.com format."
  type        = list(string)
  default = [
    "cloudbuild.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "secretmanager.googleapis.com",
    "storage.googleapis.com",
  ]
}
variable "disable_services_on_destroy" {
  description = <<EOF
Whether to disable services on destroy.
Set to `true` to disable services when the module is destroyed.
Set to `false` to leave services enabled (removed from state only).
See: https://www.terraform.io/docs/providers/google/r/google_project_service.html#disable_on_destroy
EOF
  type        = bool
  nullable    = false
  default     = false
}
variable "disable_dependent_services" {
  description = <<EOF
Whether to disable dependent services when a service is disabled.
Set to `true` to disable dependent services.
Set to `false` to leave dependent services enabled.
See: https://www.terraform.io/docs/providers/google/r/google_project_service.html#disable_dependent_services
EOF
  type        = bool
  nullable    = false
  default     = true
}

#######
# IAM #
#######
variable "tf_cloud_build_sa_roles" {
  description = "List of IAM roles to assign to the Terraform Cloud Build service account."
  type        = list(string)
  nullable    = false
  default = [
    "roles/cloudbuild.builds.builder",
    "roles/logging.logWriter",
    "roles/storage.objectUser",
    "roles/serviceusage.serviceUsageConsumer",
  ]
}

##################
# tfvars secrets #
##################
variable "tfvars_secret_id" {
  description = "The ID of the secret in Secret Manager where tfvars will be stored."
  type        = string
  nullable    = false
  default     = "tfvars"
}
variable "tfvars_secret_version_delete_ttl" {
  description = "The time to live for tfvars secret versions before they are deleted."
  type        = string
  nullable    = true
  default     = "1209600s"
}
