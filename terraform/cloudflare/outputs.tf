output "zone_id" {
  description = "Cloudflare zone ID for rubenspensky.com."
  value       = var.zone_id
}

output "homelab_tunnel_id" {
  description = "Cloudflare Tunnel ID used by Kubernetes cloudflared."
  value       = cloudflare_zero_trust_tunnel_cloudflared.homelab_k8s.id
}

output "frontend_demo_pages_project" {
  description = "Cloudflare Pages project name for frontend-demo."
  value       = cloudflare_pages_project.frontend_demo.name
}

output "frontend_demo_hostname" {
  description = "Custom hostname for the frontend-demo Pages project."
  value       = local.frontend_demo_hostname
}

output "portfolio_pages_project" {
  description = "Cloudflare Pages project name for the portfolio site."
  value       = cloudflare_pages_project.portfolio.name
}

output "portfolio_hostname" {
  description = "Custom hostname for the portfolio Pages project."
  value       = local.portfolio_hostname
}
