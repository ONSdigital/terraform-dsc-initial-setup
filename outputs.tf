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
  value       = module.log-bucket.name
}

output "cmek_key_ring_id" {
  description = "The resource name of the CMEK key ring."
  value       = google_kms_key_ring.tf-kms-key-ring.id
}

output "cmek_key_id" {
  description = "The resource name of the CMEK key."
  value       = google_kms_crypto_key.tf-kms-crypto-key.id
}
