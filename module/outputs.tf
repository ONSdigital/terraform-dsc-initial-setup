output "tf-cloud-build-sa-email" {
  description = "Email of the Terraform Cloud Build service account."
  value       = module.tf-service-account.email
}
output "tf-buckets-names" {
  description = "Names of the Terraform gcs buckets, as a map of names to bucket resources."
  value       = module.tf-gcs-buckets.names_list
  sensitive   = true # mark as sensitive to avoid exposing bucket names in logs (for state bucket especially)
}
