variable "cloudflare_account_id" {
  description = "Cloudflare account ID that owns the homelab zone and tunnel."
  type        = string
  default     = "1271f7aabb901ca249b48a3b40fac8cc"
}

variable "zone_id" {
  description = "Cloudflare zone ID for rubenspensky.com."
  type        = string
  default     = "d48f1079b7d9762c38d6c22a9c1ba639"
}

variable "zone_name" {
  description = "Primary Cloudflare DNS zone."
  type        = string
  default     = "rubenspensky.com"
}

variable "homelab_tunnel_id" {
  description = "Existing Cloudflare Tunnel ID used by Kubernetes cloudflared."
  type        = string
  default     = "858f5f9e-2dba-402e-95d5-f7300942e94b"
}

variable "homelab_tunnel_name" {
  description = "Existing Cloudflare Tunnel name used by Kubernetes cloudflared."
  type        = string
  default     = "homelab-k8s"
}

variable "homelab_tunnel_service" {
  description = "Kubernetes service reached by the Cloudflare Tunnel wildcard ingress."
  type        = string
  default     = "http://envoy-routing-homelab-gateway-adf87ad2.envoy-gateway-system.svc.cluster.local:80"
}

variable "frontend_demo_project_name" {
  description = "Cloudflare Pages project name for the first static frontend demo."
  type        = string
  default     = "frontend-demo"
}
