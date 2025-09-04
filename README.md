# terraform-dsc-initial-setup
An opinionated terraform module to perform common GCP project set-up tasks,
including:
- Enabling APIs and services
- Creating and managing:
    - A Terraform Cloud Build service account (for planning/applying in Cloud
    Build), with least privilege IAM roles.
    - GCS buckets for Terraform state remote backend and Cloud Build artifacts
    (including logs, plans, and sources), all with object IAM bindings to
    control access.
    - Secret Manager secret for tfvars variables.

## Installation

🚧 *To be added* 🚧

## Usage

A skeleton for the basic usage of this module would look like:

```hcl
module "terraform-dsc-initial-setup" {
  source = "path/to/module"
  project_id = "<PROJECT-ID>"
  project_env = "<PROJECT_ENV>" # e.g., sandbox, dev, staging, prod
  region = "<REGION>" # region where all resources will be created
  admins_owners_group_email = "<ADMINS-OWNERS-GOOGLE-GROUP-EMAIL>" # get object admin role on all tf buckets
  cloud_eng_group_email = "<CLOUD-ENG-GOOGLE-GROUP-EMAIL>" # get object creator role on all tf buckets
  apis_services = [ # List of APIs/services to be activated in the project, in XXXX.googleapis.com format.
    "cloudbuild.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "secretmanager.googleapis.com",
    "storage.googleapis.com"
  ]
  tf_cloud_build_sa_roles = [ # List of IAM roles to assign to the Terraform Cloud Build service account.
    "roles/cloudbuild.builds.builder",
    "roles/logging.logWriter",
    "roles/storage.objectUser",
    "roles/serviceusage.serviceUsageConsumer"
  ]
}
```

For a full list of configurable inputs, see the [Inputs](#inputs) section
below.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >=1.11.0, <2.0.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >=6.45.0, <7.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | 6.46.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_project-services"></a> [project-services](#module\_project-services) | terraform-google-modules/project-factory/google//modules/project_services | ~> 18.0.0 |
| <a name="module_tf-gcs-buckets"></a> [tf-gcs-buckets](#module\_tf-gcs-buckets) | terraform-google-modules/cloud-storage/google | ~> 11.0 |
| <a name="module_tf-service-account"></a> [tf-service-account](#module\_tf-service-account) | terraform-google-modules/service-accounts/google | ~> 4.0 |

## Resources

| Name | Type |
|------|------|
| [google_storage_bucket_iam_policy.tf-gcs-buckets](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_policy) | resource |
| [google_iam_policy.tf-gcs-buckets](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/iam_policy) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_admins_owners_group_email"></a> [admins\_owners\_group\_email](#input\_admins\_owners\_group\_email) | Google group email of the that will have object admin access to the terraform GCS buckets. | `string` | n/a | yes |
| <a name="input_apis_services"></a> [apis\_services](#input\_apis\_services) | List of APIs/services to be activated in the project, in XXXX.googleapis.com format. | `list(string)` | <pre>[<br/>  "cloudbuild.googleapis.com",<br/>  "cloudresourcemanager.googleapis.com",<br/>  "iam.googleapis.com",<br/>  "secretmanager.googleapis.com",<br/>  "storage.googleapis.com"<br/>]</pre> | no |
| <a name="input_cloud_eng_group_email"></a> [cloud\_eng\_group\_email](#input\_cloud\_eng\_group\_email) | Google group email of the cloud engineering team that will have object creator access to the terraform GCS buckets. | `string` | n/a | yes |
| <a name="input_disable_dependent_services"></a> [disable\_dependent\_services](#input\_disable\_dependent\_services) | Whether to disable dependent services when a service is disabled.<br/>Set to `true` to disable dependent services.<br/>Set to `false` to leave dependent services enabled.<br/>See: https://www.terraform.io/docs/providers/google/r/google_project_service.html#disable_dependent_services | `bool` | `true` | no |
| <a name="input_disable_services_on_destroy"></a> [disable\_services\_on\_destroy](#input\_disable\_services\_on\_destroy) | Whether to disable services on destroy.<br/>Set to `true` to disable services when the module is destroyed.<br/>Set to `false` to leave services enabled (removed from state only).<br/>See: https://www.terraform.io/docs/providers/google/r/google_project_service.html#disable_on_destroy | `bool` | `false` | no |
| <a name="input_project_env"></a> [project\_env](#input\_project\_env) | The environment of the project (e.g., sandbox, dev, staging, prod). | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The GCP project ID where the services will be activated. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The GCP region where the resources will be created. | `string` | `"europe-west2"` | no |
| <a name="input_tf_bucket_force_destroy"></a> [tf\_bucket\_force\_destroy](#input\_tf\_bucket\_force\_destroy) | Whether to force destroy the GCS buckets, allowing deletion of non-empty buckets.<br/>Set to `true` to allow deletion of non-empty buckets (recommended for Sandbox/Dev environments only).<br/>Set to `false` to prevent deletion of non-empty buckets (recommended for Staging/Prod environments).<br/>See: https://www.terraform.io/docs/providers/google/r/storage_bucket.html#force_destroy-1 | `bool` | `false` | no |
| <a name="input_tf_cloud_build_sa_roles"></a> [tf\_cloud\_build\_sa\_roles](#input\_tf\_cloud\_build\_sa\_roles) | List of IAM roles to assign to the Terraform Cloud Build service account. | `list(string)` | <pre>[<br/>  "roles/cloudbuild.builds.builder",<br/>  "roles/logging.logWriter",<br/>  "roles/storage.objectUser",<br/>  "roles/serviceusage.serviceUsageConsumer"<br/>]</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_tf-buckets-names"></a> [tf-buckets-names](#output\_tf-buckets-names) | Names of the Terraform gcs buckets, as a map of names to bucket resources. |
| <a name="output_tf-cloud-build-sa-email"></a> [tf-cloud-build-sa-email](#output\_tf-cloud-build-sa-email) | Email of the Terraform Cloud Build service account. |
<!-- END_TF_DOCS -->
