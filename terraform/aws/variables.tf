variable "aws_region" {
  description = "AWS region where homelab support resources are created."
  type        = string
  default     = "us-east-2"
}

variable "name_prefix" {
  description = "Consistent prefix used for homelab AWS resources."
  type        = string
  default     = "homelab"
}

variable "backup_lifecycle_expiration_days" {
  description = "Number of days before backup objects expire. Set to null to disable expiration."
  type        = number
  default     = 180
}

variable "secrets" {
  description = "Secrets Manager secret names to create. Values are intentionally not managed by Terraform."
  type        = set(string)
  default = [
    "homelab/cloudflare/tunnel-token",
    "homelab/github/arc-app",
    "homelab/aws/s3-backup",
  ]
}

variable "parameters" {
  description = "SSM Parameter Store names to create. Values are intentionally not managed by Terraform."
  type        = set(string)
  default = [
    "/homelab/authentik",
    "/homelab/umamik",
    "/homelab/grafana",
    "/homelab/sonarqube"
  ]
}
