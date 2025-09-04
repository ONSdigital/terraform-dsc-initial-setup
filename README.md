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

## Installation

🚧 *To be added* 🚧

## Features

- **APIs and Services**: Enables a core set of APIs and services, with the
option to add more. The core set includes:
  - Cloud Build API
  - Cloud Resource Manager API
  - IAM API
  - Cloud Storage API

- **Terraform Service Account**: Creates a service account for usage with
Terraform Cloud Build workflows. This has an initial set of least privilege IAM
roles, with the option to add more. The core roles include:
  - Cloud Build Service Account (roles/cloudbuild.builds.builder)
  - Logs Writer (roles/logging.logWriter)
  - Service Usage Consumer (roles/serviceusage.serviceUsageConsumer)

- **Terraform GCS**: Creates GCS buckets for Terraform state remote backend and
Terraform Cloud Build artifacts (including logs, plans, and source artifacts).
Key points include:
  - Logs, plans, and cloudbuild buckets uses autoclass and lifecycle rules to help
  manage storage costs over time (logs are auto-deleted after 365 days, plans/cloudbuild artifacts after 90 days).
  - The state-remote-backend bucket uses versioning to help protect against
  accidental deletions or overwrites of state files, and allows for older
  versions to be restored if needed.
  - All terraform buckets are subject to a strict IAM policy, granting:
    - Bucket Admin permissions to the admin/owners and cloud engineering Google
    Groups.
    - The Terraform Cloud Build service account Object user permissions (to
    allow it to read/write objects in the buckets).
    - No other principals/uses will be able to have access to these buckets.

## Usage

A basic usage of this module (accepting the optional parameters with default
values) would look like:

```hcl
module "setup" {
  source      = "path/to/module"
  project_id  = "<PROJECT-ID>"
  project_env = "<PROJECT_ENV>" # e.g., sandbox, dev, staging, prod

  # used to setup the terraform bucket IAM policies
  admins_owners_group_email = "<ADMINS-OWNERS-GOOGLE-GROUP-EMAIL>"
  cloud_eng_group_email     = "<CLOUD-ENG-GOOGLE-GROUP-EMAIL>"
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
| <a name="input_additional_apis_services"></a> [additional\_apis\_services](#input\_additional\_apis\_services) | List of additional APIs/services to be activated in the project, in XXXX.googleapis.com format.<br/>  The following APIs/services are always activated:<br/>  - cloudbuild.googleapis.com<br/>  - cloudresourcemanager.googleapis.com<br/>  - iam.googleapis.com<br/>  - storage.googleapis.com | `list(string)` | `[]` | no |
| <a name="input_additional_tf_cloud_build_sa_roles"></a> [additional\_tf\_cloud\_build\_sa\_roles](#input\_additional\_tf\_cloud\_build\_sa\_roles) | List of additional IAM roles to assign to the Terraform Cloud Build service account.<br/>  The following roles are always assigned:<br/>  - roles/cloudbuild.builds.builder<br/>  - roles/logging.logWriter<br/>  - roles/serviceusage.serviceUsageConsumer | `list(string)` | `[]` | no |
| <a name="input_admins_owners_group_email"></a> [admins\_owners\_group\_email](#input\_admins\_owners\_group\_email) | Google group email of the that will have object admin access to the terraform GCS buckets. | `string` | n/a | yes |
| <a name="input_cloud_eng_group_email"></a> [cloud\_eng\_group\_email](#input\_cloud\_eng\_group\_email) | Google group email of the cloud engineering team that will have object creator access to the terraform GCS buckets. | `string` | n/a | yes |
| <a name="input_disable_dependent_services"></a> [disable\_dependent\_services](#input\_disable\_dependent\_services) | Whether to disable dependent services when a service is disabled.<br/>Set to `true` to disable dependent services.<br/>Set to `false` to leave dependent services enabled.<br/>See: https://www.terraform.io/docs/providers/google/r/google_project_service.html#disable_dependent_services | `bool` | `true` | no |
| <a name="input_disable_services_on_destroy"></a> [disable\_services\_on\_destroy](#input\_disable\_services\_on\_destroy) | Whether to disable services on destroy.<br/>Set to `true` to disable services when the module is destroyed.<br/>Set to `false` to leave services enabled (removed from state only).<br/>See: https://www.terraform.io/docs/providers/google/r/google_project_service.html#disable_on_destroy | `bool` | `false` | no |
| <a name="input_project_env"></a> [project\_env](#input\_project\_env) | The environment of the project (e.g., sandbox, dev, staging, prod). | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The GCP project ID where the services will be activated. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The GCP region where the resources will be created. | `string` | `"europe-west2"` | no |
| <a name="input_tf_bucket_force_destroy"></a> [tf\_bucket\_force\_destroy](#input\_tf\_bucket\_force\_destroy) | Whether to force destroy the GCS buckets, allowing deletion of non-empty buckets.<br/>Set to `true` to allow deletion of non-empty buckets (recommended for Sandbox/Dev environments only).<br/>Set to `false` to prevent deletion of non-empty buckets (recommended for Staging/Prod environments).<br/>See: https://www.terraform.io/docs/providers/google/r/storage_bucket.html#force_destroy-1 | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_tf-buckets-names"></a> [tf-buckets-names](#output\_tf-buckets-names) | Names of the Terraform gcs buckets, as a map of names to bucket resources. |
| <a name="output_tf-cloud-build-sa-email"></a> [tf-cloud-build-sa-email](#output\_tf-cloud-build-sa-email) | Email of the Terraform Cloud Build service account. |
<!-- END_TF_DOCS -->
