# AGENTS.md

## Scope
- This repo is homelab bootstrap/support infra, not Kubernetes GitOps or app manifests.
- `autoinstall-os/` builds a Debian installer ISO from a local netinst ISO plus `preseed.cfg`.
- `ansible/` bootstraps Debian 13 hosts into Kubernetes 1.36 with `kubeadm`, `containerd`, Cilium, Helm, Argo CD addons, storage mounts, and optional NVIDIA host/runtime support.
- `terraform/aws/` creates AWS support resources only: S3 backups bucket, Secrets Manager secret containers, IAM users, and IAM policies.
- `terraform/cloudflare/` manages Cloudflare support resources for `rubenspensky.com`: DNS, existing tunnel remote config, and Pages projects.

## Safety
- Do not commit generated ISOs, kubeconfigs, private keys, Terraform state, `.tfvars`, local env files, IAM access keys, or secret values.
- `autoinstall-os/preseed.cfg` contains an `ops` password hash and an SSH public key; treat this repo as private.
- Kubernetes app manifests, External Secrets manifests, Velero manifests, NVIDIA GPU Operator, and NVIDIA device plugin belong in GitOps/Argo CD, not this repo.

## Autoinstall ISO
- Build from `autoinstall-os/` with `./build-iso.sh`; it does not download Debian and does not write USB drives.
- Put `debian-*-amd64-netinst.iso` beside `build-iso.sh`, set `DEBIAN_ISO_PATH`, or pass the ISO path as `./build-iso.sh /path/to/debian-13.5.0-amd64-netinst.iso`.
- Build deps are installed with `sudo apt install xorriso gzip cpio coreutils`; the script refuses `preseed.cfg` if `REPLACE_WITH_SHA512_CRYPT_HASH` remains.
- Output is `autoinstall-os/dist/debian-autoinstall-ops.iso` and must stay untracked.
- `preseed.cfg` uses the `k8s-no-swap` UEFI recipe: `/boot/efi` plus `/`, no swap; do not switch back to Debian `atomic` because systemd can autoactivate GPT swap partitions.
- Installer disk selection is destructive: prefer serial `PNY4519191104030431D`, otherwise first non-removable disk.

## Ansible
- Run Ansible from `ansible/`; `ansible.cfg` sets `inventory = inventories/lab/hosts.ini`, `roles_path = roles`, `remote_user = ops`, and disables host key checking.
- Install role collections before using storage/mount tasks: `ansible-galaxy collection install -r requirements.yaml`.
- Validate with `ansible-playbook site.yaml --syntax-check` and `ansible-playbook playbooks/cluster-addons.yaml --syntax-check`.
- Use `--limit` for focused runs, e.g. `ansible-playbook site.yaml --limit k8s-control-01` or `ansible-playbook site.yaml --limit k8s-worker-02`.
- Main inventory: `k8s-control-01=192.168.0.110`, `k8s-worker-01=192.168.0.111`, `k8s-worker-02=192.168.0.112`.
- `site.yaml` order matters: base, laptop, NVIDIA host, Kubernetes common, control plane storage/control-plane/Helm/Cilium, workers.
- Test inventory treats `k8s-worker-02` as a temporary single-node control plane: `ansible-playbook -i inventories/test-worker2-control-plane/hosts.ini site.yaml`.
- For that test inventory, addons must use the same explicit inventory: `ansible-playbook -i inventories/test-worker2-control-plane/hosts.ini playbooks/cluster-addons.yaml`.
- Do not reuse a node initialized with `kubeadm init` as a normal worker without resetting Kubernetes first.

## Storage Role
- Storage settings for `k8s-control-01` live in `ansible/inventories/lab/host_vars/k8s-control-01.yaml`; do not hardcode disk IDs in tasks.
- Never target `/dev/sda`, `/dev/sdb`, or `/dev/sdc`; use `/dev/disk/by-id` for disk operations and UUID/LABEL for mounts.
- The system disk ID is safety-check only and must never be partitioned, formatted, or mounted by the storage role.
- HDD storage is an existing ext4 filesystem mounted by UUID at `/mnt/hdd-storage`; keep `storage_hdd_format: false` and never run `community.general.filesystem` on it.
- SSD storage creates one whole-disk GPT partition, formats only that partition as ext4 with label `ssd-storage`, and mounts `LABEL=ssd-storage` at `/mnt/ssd-storage`.
- Keep the real-device assertions before any partitioning or formatting so a bad disk ID cannot touch the system disk.

## Kubernetes Bootstrap
- Kubernetes repo version is `v1.36`; cluster vars live under `ansible/inventories/*/group_vars/k8s_cluster.yaml`.
- Cilium is installed during `site.yaml` because the cluster needs a CNI before normal pods are usable.
- Argo CD is separate from `site.yaml`; install it with `ansible-playbook playbooks/cluster-addons.yaml`.
- Argo CD is exposed as `ClusterIP`; access with `kubectl -n argocd port-forward svc/argocd-server 8080:443`.

## Containerd And NVIDIA
- Debian's default `containerd` config broke Kubernetes during testing; keep explicit Kubernetes settings in `roles/containerd`.
- Required containerd values are `default_runtime_name = "runc"`, `SystemdCgroup = true`, `sandbox_image = "registry.k8s.io/pause:3.10.2"`, and CNI `bin_dir = "/opt/cni/bin"`.
- If CoreDNS is stuck in `ContainerCreating`, check events for missing `cilium-cni` or `loopback`; that usually means containerd is using `/usr/lib/cni` instead of `/opt/cni/bin`.
- NVIDIA support in Ansible is host/runtime only; do not install NVIDIA GPU Operator, NVIDIA device plugin, RuntimeClasses, or CUDA application libraries here.
- The current GPU target is `k8s-control-01` with a GTX 1060 6GB; hosts can be in both `control_plane` and `gpu`.
- `roles/containerd` adds the `nvidia` runtime block only for hosts in `gpu` but keeps `runc` as default for future RuntimeClass use.
- After first installing `nvidia-driver`, a reboot may be required before `nvidia-smi` works.
- Validate host/runtime with `nvidia-smi` and `containerd config dump | grep -E 'default_runtime_name|nvidia-container-runtime|SystemdCgroup'`.

## Terraform AWS
- Run Terraform from `terraform/aws/`.
- Validate with `terraform fmt -check -recursive` and `terraform validate` after `terraform init` has installed providers.
- Terraform requires `>= 1.6.0` and AWS provider `~> 5.0`.
- Terraform state uses S3 backend bucket `homelab-tf-state-rubenspensky`, key `infra/aws/terraform.tfstate`, region `us-east-2`, and S3 native `use_lockfile = true`; do not add DynamoDB locking.
- Defaults are `aws_region = "us-east-2"`, `name_prefix = "homelab"`, and backup expiration after `180` days.
- Managed secrets are containers only: `homelab/cloudflare/tunnel-token`, `homelab/github/arc-app`, and `homelab/aws/s3-backup`; put values with `aws secretsmanager put-secret-value`, not Terraform.
- IAM users are `homelab-s3-backups` and `homelab-secrets-reader`; create access keys manually with `aws iam create-access-key` so keys do not land in Terraform state.
- The backups bucket name is `homelab-backups-<aws-account-id>` and has versioning, SSE-S3 encryption, public access blocking, and lifecycle expiration.

## Terraform Cloudflare
- Run Terraform from `terraform/cloudflare/`.
- Validate with `terraform fmt -check -recursive` and `terraform validate` after `terraform init` has installed providers.
- Terraform state uses S3 backend bucket `homelab-tf-state-rubenspensky`, key `infra/cloudflare/terraform.tfstate`, region `us-east-2`, and S3 native `use_lockfile = true`.
- The Cloudflare provider uses `CLOUDFLARE_API_TOKEN`; do not commit tokens, `.tfvars`, state, tunnel tokens, or Pages deployment artifacts.
- Keep the existing `homelab-k8s` tunnel imported rather than recreating it unless explicitly requested; Kubernetes already depends on its working `cloudflared` token.
- Preserve tunnel `config_src = "cloudflare"` so remote config remains managed by Cloudflare/Terraform.
- `*.rubenspensky.com` points to the Kubernetes tunnel; specific DNS records such as `frontend-demo.rubenspensky.com` can override the wildcard for Pages.
- The first Pages project is `frontend-demo` with custom hostname `frontend-demo.rubenspensky.com`.
- Cloudflare Pages deployment contents are not managed here; deploy static builds separately, for example with Wrangler direct upload.
- For future Pages sites, prefer a Terraform map/`for_each` for projects, DNS, and domains, while CI/CD handles build and `wrangler pages deploy`.
