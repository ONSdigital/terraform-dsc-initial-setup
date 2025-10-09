output "tf-cloud-build-sa-email" {
  description = "Email of the Terraform Cloud Build service account."
  value       = module.tf-service-account.email
}
output "tf-bucket-names" {
  description = "Map of logical bucket suffixes (state, plans, cloudbuild) to their GCS bucket names."
  value       = module.tf-gcs-buckets.names
}

output "log_bucket_name" {
  description = "Name of the log bucket."
  value       = module.log_bucket.name
}
