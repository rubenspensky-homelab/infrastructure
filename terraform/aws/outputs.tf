output "aws_region" {
  description = "AWS region used by this project."
  value       = var.aws_region
}

output "backups_bucket_name" {
  description = "S3 bucket name for Velero and database backups."
  value       = aws_s3_bucket.backups.id
}

output "backups_bucket_arn" {
  description = "S3 bucket ARN for backups."
  value       = aws_s3_bucket.backups.arn
}

output "s3_backups_user_name" {
  description = "IAM user with read/write access to the backups bucket."
  value       = aws_iam_user.s3_backups.name
}

output "secrets_reader_user_name" {
  description = "IAM user with read-only access to homelab secrets."
  value       = aws_iam_user.secrets_reader.name
}

output "secret_arns" {
  description = "Secrets Manager ARNs created by this project."
  value       = { for name, secret in aws_secretsmanager_secret.homelab : name => secret.arn }
}
