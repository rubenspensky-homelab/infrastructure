resource "cloudflare_pages_project" "frontend_demo" {
  account_id        = var.cloudflare_account_id
  name              = var.frontend_demo_project_name
  production_branch = "main"
}

resource "cloudflare_pages_domain" "frontend_demo" {
  account_id   = var.cloudflare_account_id
  project_name = cloudflare_pages_project.frontend_demo.name
  name         = local.frontend_demo_hostname

  depends_on = [cloudflare_dns_record.frontend_demo_pages]
}
