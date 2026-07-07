resource "aws_secretsmanager_secret" "homelab" {
  for_each = var.secrets

  name                    = each.value
  recovery_window_in_days = 7
}
