resource "aws_ssm_parameter" "homelab" {
  for_each = var.parameters

  name  = each.value
  type  = "SecureString"
  value = "managed-outside-terraform"

  lifecycle {
    ignore_changes = [value]
  }
}
