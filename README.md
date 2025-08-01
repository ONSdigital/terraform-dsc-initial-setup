# terraform-dsc-initial-setup
A terraform module to perform common GCP project set-up tasks

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >=1.11.0, <2.0.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >=6.45.0, <7.0.0 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | >=6.45.0, <7.0.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_project-services"></a> [project-services](#module\_project-services) | terraform-google-modules/project-factory/google//modules/project_services | ~> 18.0.0 |
| <a name="module_tf-service-account"></a> [tf-service-account](#module\_tf-service-account) | terraform-google-modules/service-accounts/google | ~> 4.0 |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_apis_services"></a> [apis\_services](#input\_apis\_services) | List of APIs/services to be activated in the project, in XXXX.googleapis.com format. | `list(string)` | n/a | yes |
| <a name="input_disable_dependent_services"></a> [disable\_dependent\_services](#input\_disable\_dependent\_services) | Whether to disable dependent services when a service is disabled.<br/>Set to `true` to disable dependent services.<br/>Set to `false` to leave dependent services enabled.<br/>See: https://www.terraform.io/docs/providers/google/r/google_project_service.html#disable_dependent_services | `bool` | `true` | no |
| <a name="input_disable_services_on_destroy"></a> [disable\_services\_on\_destroy](#input\_disable\_services\_on\_destroy) | Whether to disable services on destroy.<br/>Set to `true` to disable services when the module is destroyed.<br/>Set to `false` to leave services enabled (removed from state only).<br/>See: https://www.terraform.io/docs/providers/google/r/google_project_service.html#disable_on_destroy | `bool` | `false` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The GCP project ID where the services will be activated. | `string` | n/a | yes |
| <a name="input_tf_cloud_build_sa_roles"></a> [tf\_cloud\_build\_sa\_roles](#input\_tf\_cloud\_build\_sa\_roles) | List of IAM roles to assign to the Terraform Cloud Build service account. | `list(string)` | <pre>[<br/>  "roles/cloudbuild.builds.builder",<br/>  "roles/logging.logWriter",<br/>  "roles/storage.objectUser",<br/>  "roles/serviceusage.serviceUsageConsumer"<br/>]</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_tf-cloud-build-sa-email"></a> [tf-cloud-build-sa-email](#output\_tf-cloud-build-sa-email) | Email of the Terraform Cloud Build service account. |
<!-- END_TF_DOCS -->
