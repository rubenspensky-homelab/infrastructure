# AGENTS.md

## Scope

- This repo is homelab bootstrap/support infra, not Kubernetes GitOps or app manifests.
- `autoinstall-os/` builds a Debian installer ISO from a local netinst ISO plus `preseed.cfg`.
- `ansible/` bootstraps Debian 13 hosts into a Kubernetes 1.36 cluster with `kubeadm`, `containerd`, Cilium, Helm, Argo CD addons, and optional NVIDIA host/runtime support.
- `terraform/aws/` creates AWS support resources: one S3 backups bucket, Secrets Manager secret containers, and IAM users/policies; it intentionally does not create IAM access keys or secret values.

## Safety

- Do not commit generated ISOs, kubeconfigs, private keys, Terraform state, `.tfvars`, local env files, IAM access keys, or secret values.
- `autoinstall-os/preseed.cfg` contains an `ops` password hash and an SSH public key; treat this repo as private.
- Kubernetes app manifests, External Secrets manifests, Velero manifests, NVIDIA GPU Operator, and NVIDIA device plugin belong in GitOps/Argo CD, not this repo.

## Autoinstall ISO

- Build from `autoinstall-os/` with `./build-iso.sh`; the script does not download Debian and does not write USB drives.
- Put a Debian amd64 netinst ISO next to `build-iso.sh` or pass it explicitly: `./build-iso.sh /path/to/debian-13.5.0-amd64-netinst.iso`.
- The build requires `xorriso gzip cpio coreutils` and refuses to run if `preseed.cfg` still contains `REPLACE_WITH_SHA512_CRYPT_HASH`.
- Output is `autoinstall-os/dist/debian-autoinstall-ops.iso` and must stay untracked.
- `preseed.cfg` uses the `k8s-no-swap` UEFI partition recipe: `/boot/efi` plus `/`, no swap partition. Do not switch back to Debian `atomic`; systemd can autoactivate GPT swap partitions even when `/etc/fstab` is commented.

## Ansible

- Run Ansible from `ansible/`; `ansible.cfg` sets `inventory = inventories/lab/hosts.ini`, `roles_path = roles`, `remote_user = ops`, and disables host key checking.
- Validate syntax with `ansible-playbook site.yaml --syntax-check` and `ansible-playbook playbooks/cluster-addons.yaml --syntax-check`.
- Use `--limit` for focused runs, e.g. `ansible-playbook site.yaml --limit k8s-worker-02` or `ansible-playbook site.yaml --limit k8s-control-01`.
- Main lab inventory: `k8s-control-01` is `192.168.0.110`, `k8s-worker-01` is `192.168.0.111`, and `k8s-worker-02` is `192.168.0.112`.
- `site.yaml` order matters: base, laptop config, NVIDIA host config, Kubernetes common, control plane, workers.
- The test inventory treats `k8s-worker-02` as a temporary single-node control plane: `ansible-playbook -i inventories/test-worker2-control-plane/hosts.ini site.yaml`.
- For that test inventory, addons must use the same explicit inventory: `ansible-playbook -i inventories/test-worker2-control-plane/hosts.ini playbooks/cluster-addons.yaml`.
- Do not reuse a node initialized with `kubeadm init` as a normal worker without resetting Kubernetes first.

## Kubernetes Bootstrap

- Kubernetes repo version is `v1.36`; cluster vars live under `ansible/inventories/*/group_vars/k8s_cluster.yaml`.
- Cilium is installed during `site.yaml` because the cluster needs a CNI before normal pods are usable.
- Argo CD is separate from `site.yaml`; install it with `ansible-playbook playbooks/cluster-addons.yaml`.
- Argo CD is exposed as `ClusterIP`; access with `kubectl -n argocd port-forward svc/argocd-server 8080:443`.

## Containerd And NVIDIA

- Debian's default `containerd` config caused `kube-apiserver` crashes during testing; keep Kubernetes 1.36 settings explicit in `roles/containerd`.
- Required containerd settings: `default_runtime_name = "runc"`, `SystemdCgroup = true`, `sandbox_image = "registry.k8s.io/pause:3.10.2"`, and CNI `bin_dir = "/opt/cni/bin"`.
- If CoreDNS is stuck in `ContainerCreating`, check events for missing `cilium-cni` or `loopback`; that usually means containerd is using `/usr/lib/cni` instead of `/opt/cni/bin`.
- NVIDIA support in Ansible is host/runtime only; do not install NVIDIA GPU Operator, NVIDIA device plugin, RuntimeClasses, or CUDA application libraries here.
- The current GPU target is `k8s-control-01` with a GTX 1060 6GB on Debian 13; hosts can be in both `control_plane` and `gpu`.
- `roles/containerd` adds the `nvidia` runtime block only for hosts in the `gpu` group, but keeps `runc` as the default runtime for future RuntimeClass use.
- After first installing `nvidia-driver`, a reboot may be required before `nvidia-smi` works.
- Validate host/runtime with `nvidia-smi` and `containerd config dump | grep -E 'default_runtime_name|nvidia-container-runtime|SystemdCgroup'`.

## Terraform AWS

- Run Terraform from `terraform/aws/`.
- Validate with `terraform fmt -check -recursive` and `terraform validate`.
- Terraform requires `>= 1.6.0` and AWS provider `~> 5.0`.
- Terraform state uses S3 backend bucket `homelab-tf-state-rubenspensky`, key `infra/aws/terraform.tfstate`, region `us-east-2`, and S3 native `use_lockfile = true`; do not add DynamoDB locking.
- Defaults are `aws_region = "us-east-2"`, `name_prefix = "homelab"`, and backup expiration after `180` days.
- Managed secrets are containers only: `homelab/cloudflare/tunnel-token`, `homelab/github/arc-app`, and `homelab/aws/s3-backup`; put values with `aws secretsmanager put-secret-value`, not Terraform.
- IAM users are `homelab-s3-backups` and `homelab-secrets-reader`; create access keys manually with `aws iam create-access-key` so keys do not land in Terraform state.
- The backups bucket name is `homelab-backups-<aws-account-id>` and has versioning, SSE-S3 encryption, public access blocking, and lifecycle expiration.
