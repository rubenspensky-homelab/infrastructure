resource "cloudflare_zero_trust_tunnel_cloudflared" "homelab_k8s" {
  account_id = var.cloudflare_account_id
  config_src = "cloudflare"
  name       = var.homelab_tunnel_name
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "homelab_k8s" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homelab_k8s.id

  config = {
    ingress = [
      {
        hostname = local.homelab_wildcard_hostname
        service  = var.homelab_tunnel_service
      },
      {
        service = "http_status:404"
      }
    ]

    warp_routing = {
      enabled = false
    }
  }
}

import {
  to = cloudflare_zero_trust_tunnel_cloudflared.homelab_k8s
  id = "${var.cloudflare_account_id}/${var.homelab_tunnel_id}"
}

import {
  to = cloudflare_zero_trust_tunnel_cloudflared_config.homelab_k8s
  id = "${var.cloudflare_account_id}/${var.homelab_tunnel_id}"
}
