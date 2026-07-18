# Homelab Cloudflare Terraform

This project manages Cloudflare support resources for `rubenspensky.com`: DNS, the existing Kubernetes Cloudflare Tunnel remote configuration, and Cloudflare Pages projects.

It uses the `CLOUDFLARE_API_TOKEN` environment variable. Do not commit tokens, `.tfvars`, Terraform state, or tunnel secrets.

Terraform state is stored in the S3 bucket `homelab-tf-state-rubenspensky` using the key `infra/cloudflare/terraform.tfstate`.

## Resources

- Zone: `rubenspensky.com`
- Existing tunnel: `homelab-k8s`
- DNS: `*.rubenspensky.com` points to the tunnel
- Pages project: `frontend-demo`
- Pages domain: `frontend-demo.rubenspensky.com`

The tunnel is imported instead of recreated because it is already healthy and Kubernetes already has a working `cloudflared` token.

The wildcard DNS record sends normal homelab subdomains to Kubernetes. More specific records, such as `frontend-demo.rubenspensky.com`, override the wildcard and can point to Cloudflare Pages.

## Usage

```sh
terraform init
terraform plan
terraform apply
```

The first apply imports the existing tunnel, tunnel remote config, and wildcard DNS record into Terraform state, then creates the Pages project and its custom domain.

## Static Deploys

The simplest deploy path for `frontend-demo` is direct upload with Wrangler from the frontend build directory:

```sh
npx wrangler pages deploy dist --project-name frontend-demo
```

Wrangler uses `CLOUDFLARE_API_TOKEN` from the environment when it is set. For local manual use, `npx wrangler login` can also provide credentials.

Cloudflare Pages deployment contents are intentionally not managed by Terraform. Terraform creates projects, DNS, and custom domains; CI/CD builds and uploads static assets.

## Future Pages Sites

For more static sites, prefer a Terraform map with `for_each` so each site declares its project name, hostname, and production branch in one place. The CI/CD pipeline for each site should deploy to the matching Pages project with Wrangler.

Example shape:

```hcl
pages_sites = {
  frontend-demo = {
    hostname          = "frontend-demo.rubenspensky.com"
    production_branch = "main"
  }
}
```

Recommended split:

- Terraform manages Cloudflare Pages projects, DNS records, and Pages custom domains.
- CI/CD runs application tests, builds static assets, and deploys with Wrangler.
- Static build artifacts, deployment tokens, and Pages output directories stay out of this repo.

Typical CI/CD deploy command:

```sh
npx wrangler pages deploy dist --project-name "$PAGES_PROJECT_NAME" --branch "$BRANCH_NAME"
```

Git-backed Pages deployments can be added later if Cloudflare should own the build step directly.
