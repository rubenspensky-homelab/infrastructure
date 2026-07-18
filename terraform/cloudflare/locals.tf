locals {
  homelab_wildcard_hostname    = "*.${var.zone_name}"
  homelab_tunnel_cname_content = "${var.homelab_tunnel_id}.cfargotunnel.com"
  frontend_demo_hostname       = "frontend-demo.${var.zone_name}"
}
