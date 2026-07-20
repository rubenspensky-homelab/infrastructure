# Homelab Cloudflare Terraform

This project manages Cloudflare support resources for `rubenspensky.com`: DNS, the existing Kubernetes Cloudflare Tunnel remote configuration, and Cloudflare Pages projects.

It uses the `CLOUDFLARE_API_TOKEN` environment variable. Do not commit tokens, `.tfvars`, Terraform state, or tunnel secrets.

Terraform state is stored in the S3 bucket `homelab-tf-state-rubenspensky` using the key `infra/cloudflare/terraform.tfstate`.

## Resources

- Zone: `rubenspensky.com`
- Existing tunnel: `homelab-k8s`
- DNS: `*.rubenspensky.com` points to the tunnel
- Pages project: `frontend-demo`, connected to `rubenspensky-homelab/frontend-demo`
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

## Pages Deploys

The `frontend-demo` Pages project is connected to GitHub repo `rubenspensky-homelab/frontend-demo`. Cloudflare builds production deployments from the `main` branch with:

```sh
npm ci && npm run build
```

The build output directory is `dist`. After Terraform applies the Pages project source and build config, pushes to `main` trigger Cloudflare Pages deployments automatically.

Cloudflare Pages deployment contents are intentionally not managed by Terraform. Terraform creates projects, DNS, custom domains, and the Git/build configuration; Cloudflare Pages builds and deploys static assets.

## Future Pages Sites

For more static sites, prefer a Terraform map with `for_each` so each site declares its project name, hostname, production branch, Git repo, and build settings in one place.

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

- Terraform manages Cloudflare Pages projects, DNS records, Pages custom domains, and Git/build configuration.
- Cloudflare Pages builds static assets and deploys when the source repo changes.
- Static build artifacts, deployment tokens, and Pages output directories stay out of this repo.
