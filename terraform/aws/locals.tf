locals {
  tags = {
    Project     = var.name_prefix
    ManagedBy   = "terraform"
    Environment = "homelab"
  }
}
