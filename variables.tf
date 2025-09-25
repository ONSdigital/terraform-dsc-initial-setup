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
  default     = "europe-west2"
}

################
# API SERVICES #
################
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
variable "additional_tf_cloud_build_sa_roles" {
  description = <<EOF
  List of additional IAM roles to assign to the Terraform Cloud Build service account.
  The following roles are always assigned:
  - roles/cloudbuild.builds.builder
  - roles/logging.logWriter
  - roles/serviceusage.serviceUsageConsumer
  EOF
  type        = list(string)
  nullable    = false
  default     = []
}

##################
# tfvars buckets #
##################
variable "admins_owners_group_email" {
  description = "Google group email of the that will have object admin access to the terraform GCS buckets."
  type        = string
  nullable    = false
}

variable "gcs_object_users" {
  description = "List of principals (user, serviceAccount, group, or domain) to grant read-only access. Each entry must be in the form: user:email, serviceAccount:email, group:email, or domain:domain."
  type        = list(string)
  nullable    = false
  default     = []
  validation {
    condition = alltrue([
      for v in var.gcs_object_users :
      can(regex("^(user:[^@]+@[^@]+|serviceAccount:[^@]+@[^@]+|group:[^@]+@[^@]+|domain:[a-zA-Z0-9.-]+)$", v))
    ])
    error_message = "Each entry must be: user:email, serviceAccount:email, group:email, or domain:domain."
  }
}

variable "tf_bucket_force_destroy" {
  description = <<EOF
Whether to force destroy the GCS buckets, allowing deletion of non-empty buckets.
Set to `true` to allow deletion of non-empty buckets (recommended for Sandbox/Dev environments only).
Set to `false` to prevent deletion of non-empty buckets (recommended for Staging/Prod environments).
See: https://www.terraform.io/docs/providers/google/r/storage_bucket.html#force_destroy-1
EOF
  type        = bool
  nullable    = false
  default     = false
}
