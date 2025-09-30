output "tf-cloud-build-sa-email" {
  description = "Email of the Terraform Cloud Build service account."
  value       = module.tf-service-account.email
}
output "tf-buckets-names" {
  description = "Map of bucket suffixes to bucket names. For example: { state = <bucket_name>, logs = <bucket_name>, ... }"
  value       = module.tf-gcs-buckets.names
}
