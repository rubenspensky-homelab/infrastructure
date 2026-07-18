# Homelab Infra

This repository contains host bootstrap and supporting infrastructure code for the homelab.

It is separate from the Kubernetes GitOps repositories. This repo is for preparing machines and external support services; Kubernetes manifests remain in the GitOps source-of-truth repos.

## Scope

Current and planned areas:

- `autoinstall-os/`: Debian automated installer ISO builder using preseed.
- `ansible/`: host configuration and Kubernetes bootstrap automation.
- `terraform/`: AWS and Cloudflare support infrastructure.

## Repository Layout

```text
infra/
  README.md
  .gitignore
  autoinstall-os/
    README.md
    build-iso.sh
    preseed.cfg
  ansible/
    README.md
    inventory/
    playbooks/
    roles/
  terraform/
    README.md
    aws/
      README.md
      *.tf
    cloudflare/
      README.md
      *.tf
```

`autoinstall-os/`, `ansible/`, `terraform/aws/`, and `terraform/cloudflare/` are currently implemented.

## What Belongs Here

- Bare-metal/bootstrap automation.
- Debian autoinstall assets.
- Ansible playbooks and roles for host configuration.
- Terraform for external support infrastructure such as AWS secrets and backup buckets.
- Terraform for Cloudflare DNS, tunnel remote config, and Pages projects.
- Operational documentation for the bootstrap flow.

## What Does Not Belong Here

- Kubernetes GitOps manifests.
- Application manifests.
- Generated installer ISOs.
- Terraform state files.
- Secrets, private keys, kubeconfigs, or local environment files.

## Git Hygiene

The repository ignores generated and sensitive files, including:

- `*.iso`
- `autoinstall-os/dist/`
- `autoinstall-os/work/`
- `.terraform/`
- `*.tfstate`
- `*.tfvars`
- `.env*`
- private keys and certificate bundles

`autoinstall-os/preseed.cfg` contains an `ops` password hash and an authorized SSH public key. Treat this repository as private, or rotate the password hash before publishing it elsewhere.

Before committing, always review:

```sh
git status
git diff --cached
```

## Autoinstall OS

The current implemented workflow is in `autoinstall-os/`.

```sh
cd autoinstall-os
./build-iso.sh
```

The Debian netinst ISO must be downloaded manually and placed next to `build-iso.sh`, or passed explicitly:

```sh
./build-iso.sh /path/to/debian-amd64-netinst.iso
```

Generated output is ignored by Git:

```text
autoinstall-os/dist/debian-autoinstall-ops.iso
```

## Ansible

The Kubernetes host bootstrap workflow is in `ansible/`.

```sh
cd ansible
ansible-playbook site.yaml --limit k8s-worker-02 --check
```

See `ansible/README.md` for the full worker-only test, temporary single-node control plane test, full cluster bootstrap, and Argo CD addon steps.

The current validated Ansible path can bootstrap `k8s-worker-02` as a temporary single-node Kubernetes 1.36 control plane with Cilium and Argo CD. The normal target topology remains one PC control plane plus two laptop workers.

## Terraform Cloudflare

Cloudflare support resources are managed from `terraform/cloudflare/`.

```sh
cd terraform/cloudflare
terraform init
terraform plan
```

This stack uses `CLOUDFLARE_API_TOKEN` from the environment and the S3 backend key `infra/cloudflare/terraform.tfstate`.

It imports the existing healthy `homelab-k8s` tunnel and keeps `config_src = "cloudflare"` so tunnel remote config remains managed by Cloudflare/Terraform without rotating the Kubernetes `cloudflared` token.

Current Cloudflare resources:

- `*.rubenspensky.com` points to the Kubernetes Cloudflare Tunnel.
- `frontend-demo` is the first Cloudflare Pages project.
- `frontend-demo.rubenspensky.com` is a specific Pages hostname that overrides the wildcard DNS record.

Pages deployments are handled outside Terraform. From a static frontend build directory, deploy with Wrangler:

```sh
npx wrangler pages deploy dist --project-name frontend-demo
```

For future static sites, keep Terraform responsible for Pages projects, DNS, and custom domains, and keep CI/CD responsible for build and deploy.
