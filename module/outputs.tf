output "tf-cloud-build-sa-email" {
  description = "Email of the Terraform Cloud Build service account."
  value       = module.tf-service-account.email
}
