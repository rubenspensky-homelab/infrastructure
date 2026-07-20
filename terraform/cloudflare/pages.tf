resource "cloudflare_pages_project" "frontend_demo" {
  account_id        = var.cloudflare_account_id
  name              = var.frontend_demo_project_name
  production_branch = "main"

  source = {
    type = "github"

    config = {
      owner                          = "rubenspensky-homelab"
      repo_name                      = "frontend-demo"
      production_branch              = "main"
      pr_comments_enabled            = true
      production_deployments_enabled = true
      preview_deployment_setting     = "all"
    }
  }

  build_config = {
    build_command   = "npm ci && npm run build"
    destination_dir = "dist"
    root_dir        = ""
  }
}

resource "cloudflare_pages_domain" "frontend_demo" {
  account_id   = var.cloudflare_account_id
  project_name = cloudflare_pages_project.frontend_demo.name
  name         = local.frontend_demo_hostname

  depends_on = [cloudflare_dns_record.frontend_demo_pages]
}

resource "cloudflare_pages_project" "portfolio" {
  account_id        = var.cloudflare_account_id
  name              = var.portfolio_project_name
  production_branch = "main"

  source = {
    type = "github"

    config = {
      owner                          = "rubenspensky-homelab"
      repo_name                      = "portfolio"
      production_branch              = "main"
      pr_comments_enabled            = true
      production_deployments_enabled = true
      preview_deployment_setting     = "all"
    }
  }

  build_config = {
    build_command   = "npm ci && npm run build"
    destination_dir = "dist"
    root_dir        = ""
  }
}

resource "cloudflare_pages_domain" "portfolio" {
  account_id   = var.cloudflare_account_id
  project_name = cloudflare_pages_project.portfolio.name
  name         = local.portfolio_hostname

  depends_on = [cloudflare_dns_record.portfolio_pages]
}
