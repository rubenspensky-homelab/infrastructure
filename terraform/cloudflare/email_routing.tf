resource "cloudflare_email_routing_address" "ruben_gmail" {
  account_id = var.cloudflare_account_id
  email      = "rubenvelazquez244@gmail.com"
}

resource "cloudflare_email_routing_dns" "rubenspensky" {
  zone_id = var.zone_id
}

resource "cloudflare_email_routing_rule" "ruben_alias" {
  zone_id  = var.zone_id
  name     = "Forward ruben@rubenspensky.com to Gmail"
  enabled  = true
  priority = 0

  matchers = [{
    type  = "literal"
    field = "to"
    value = "ruben@${var.zone_name}"
  }]

  actions = [{
    type  = "forward"
    value = [cloudflare_email_routing_address.ruben_gmail.email]
  }]
}
