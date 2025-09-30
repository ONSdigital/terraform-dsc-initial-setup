
# terraform-dsc-initial-setup

This Terraform module provides a secure, opinionated setup for Google Cloud Platform (GCP) projects, automating:

- Enabling core GCP APIs
- Creating a least-privilege Terraform Cloud Build service account
- Provisioning and securing GCS buckets for Terraform state and CI/CD artifacts
- Managing KMS key rings and crypto keys for bucket encryption
- Granting required permissions to service accounts and groups

## Features

- **API Enablement**: Automatically enables Cloud Build, Cloud KMS, Cloud Resource Manager, IAM, and Cloud Storage APIs for your project.

- **Terraform Cloud Build Service Account**: Creates a dedicated service account for Terraform operations in Cloud Build, with core and optional IAM roles.

- **GCS Buckets for Terraform**: Provisions buckets for state, logs, plans, and build artifacts. Features:
  - Strict IAM policies (admin and object user roles)
  - Autoclass and lifecycle rules for cost and retention
  - Versioning for state bucket
  - CMEK encryption with a managed KMS key

- **KMS Key Management**: Creates a KMS key ring and crypto key for bucket encryption, with configurable rotation period and enforced usage by GCS.

- **IAM Policy Management**: Assigns roles to groups and service accounts for secure, least-privilege access.

## Usage

Minimal example:

```hcl
module "setup" {
  source     = "path/to/module"
  version    = "x.x.x"
  project_id = "my-gcp-project"

  storage_admins_group_email = "my-admins@ons.gov.uk"
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >=1.11.0, <2.0.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >=6.45.0, <7.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | 6.50.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_project-services"></a> [project-services](#module\_project-services) | terraform-google-modules/project-factory/google//modules/project_services | ~> 18.0.0 |
| <a name="module_tf-gcs-buckets"></a> [tf-gcs-buckets](#module\_tf-gcs-buckets) | terraform-google-modules/cloud-storage/google | ~> 11.0 |
| <a name="module_tf-service-account"></a> [tf-service-account](#module\_tf-service-account) | terraform-google-modules/service-accounts/google | ~> 4.0 |

## Resources

| Name | Type |
|------|------|
| [google_kms_crypto_key.tf-kms-crypto-key](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key) | resource |
| [google_kms_crypto_key_iam_member.gcs_service_agent](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key_iam_member) | resource |
| [google_kms_key_ring.tf-kms-key-ring](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_key_ring) | resource |
| [google_storage_bucket_iam_policy.tf-gcs-buckets](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_policy) | resource |
| [google_iam_policy.tf-gcs-buckets](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/iam_policy) | data source |
| [google_project.project](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_api_services"></a> [additional\_api\_services](#input\_additional\_api\_services) | List of additional API services to enable in the project.<br/>The following services are always enabled:<br/>- cloudbuild.googleapis.com<br/>- iam.googleapis.com<br/>- storage.googleapis.com<br/>- cloudkms.googleapis.com<br/>- cloudresourcemanager.googleapis.com | `list(string)` | `[]` | no |
| <a name="input_additional_tf_cloud_build_sa_roles"></a> [additional\_tf\_cloud\_build\_sa\_roles](#input\_additional\_tf\_cloud\_build\_sa\_roles) | List of additional IAM roles to assign to the Terraform Cloud Build service account.<br/>  The following roles are always assigned:<br/>  - roles/cloudbuild.builds.builder<br/>  - roles/logging.logWriter<br/>  - roles/serviceusage.serviceUsageConsumer | `list(string)` | `[]` | no |
| <a name="input_disable_dependent_services"></a> [disable\_dependent\_services](#input\_disable\_dependent\_services) | Whether to disable dependent services when a service is disabled.<br/>Set to `true` to disable dependent services.<br/>Set to `false` to leave dependent services enabled.<br/>See: https://www.terraform.io/docs/providers/google/r/google_project_service.html#disable_dependent_services | `bool` | `true` | no |
| <a name="input_disable_services_on_destroy"></a> [disable\_services\_on\_destroy](#input\_disable\_services\_on\_destroy) | Whether to disable services on destroy.<br/>Set to `true` to disable services when the module is destroyed.<br/>Set to `false` to leave services enabled (removed from state only).<br/>See: https://www.terraform.io/docs/providers/google/r/google_project_service.html#disable_on_destroy | `bool` | `false` | no |
| <a name="input_gcs_object_users"></a> [gcs\_object\_users](#input\_gcs\_object\_users) | List of principals (user, serviceAccount, group, or domain) to grant read-only access. Each entry must be in the form: user:email, serviceAccount:email, group:email, or domain:domain. | `list(string)` | `[]` | no |
| <a name="input_kms_key_rotation_period"></a> [kms\_key\_rotation\_period](#input\_kms\_key\_rotation\_period) | The rotation period for the KMS key ring.<br/>Must be at least 24 hours (86,400 seconds) and at most 876,000 hours (100 years, 315,360,000 seconds).<br/>Specify as a duration in seconds, e.g., "2592000s" for 30 days (2,592,000 seconds = 720 hours).<br/>Defaults to 30 days. | `string` | `"2592000s"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The GCP project ID where the services will be activated. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The GCP region where the resources will be created. | `string` | `"europe-west2"` | no |
| <a name="input_storage_admins_group_email"></a> [storage\_admins\_group\_email](#input\_storage\_admins\_group\_email) | Google group email of the that will have object admin access to the terraform GCS buckets. | `string` | n/a | yes |
| <a name="input_tf_bucket_force_destroy"></a> [tf\_bucket\_force\_destroy](#input\_tf\_bucket\_force\_destroy) | Whether to force destroy the GCS buckets, allowing deletion of non-empty buckets.<br/>Set to `true` to allow deletion of non-empty buckets (recommended for Sandbox/Dev environments only).<br/>Set to `false` to prevent deletion of non-empty buckets (recommended for Staging/Prod environments).<br/>See: https://www.terraform.io/docs/providers/google/r/storage_bucket.html#force_destroy-1 | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_tf-bucket-names"></a> [tf-bucket-names](#output\_tf-bucket-names) | Map of logical bucket suffixes (state, logs, plans, cloudbuild) to their GCS bucket names. |
| <a name="output_tf-cloud-build-sa-email"></a> [tf-cloud-build-sa-email](#output\_tf-cloud-build-sa-email) | Email of the Terraform Cloud Build service account. |
<!-- END_TF_DOCS -->
