# Homelab Infra

This repository contains host bootstrap and supporting infrastructure code for the homelab.

It is separate from the Kubernetes GitOps repositories. This repo is for preparing machines and external support services; Kubernetes manifests remain in the GitOps source-of-truth repos.

## Scope

Current and planned areas:

- `autoinstall-os/`: Debian automated installer ISO builder using preseed.
- `ansible/`: planned host configuration and post-install automation.
- `terraform/`: planned AWS infrastructure for secrets and S3 backups.

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
      secrets/
      backups/
```

Only `autoinstall-os/` exists today. The Ansible and Terraform directories are intentionally left as planned structure until implemented.

## What Belongs Here

- Bare-metal/bootstrap automation.
- Debian autoinstall assets.
- Ansible playbooks and roles for host configuration.
- Terraform for external support infrastructure such as AWS secrets and backup buckets.
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
