resource "cloudflare_dns_record" "homelab_wildcard" {
  zone_id = var.zone_id
  name    = local.homelab_wildcard_hostname
  type    = "CNAME"
  content = local.homelab_tunnel_cname_content
  proxied = true
  ttl     = 1
}

resource "cloudflare_dns_record" "frontend_demo_pages" {
  zone_id = var.zone_id
  name    = local.frontend_demo_hostname
  type    = "CNAME"
  content = cloudflare_pages_project.frontend_demo.subdomain
  proxied = true
  ttl     = 1
}

import {
  to = cloudflare_dns_record.homelab_wildcard
  id = "${var.zone_id}/538bef16ddb86ac595b13e99a789f004"
}
