# AGENTS.md

## Scope

- This repo is homelab bootstrap/support infra, not Kubernetes GitOps or app manifests.
- `autoinstall-os/` builds a Debian installer ISO from a local netinst ISO plus `preseed.cfg`.
- `ansible/` bootstraps Debian hosts into a Kubernetes 1.36 cluster with `kubeadm`, `containerd`, Cilium, Helm, Argo CD addons, and optional NVIDIA host/runtime support.
- `terraform/aws/` creates AWS support resources: one S3 backups bucket, Secrets Manager secret containers, and IAM users/policies; it intentionally does not create access keys or secret values.

## Safety

- Do not commit generated ISOs, kubeconfigs, private keys, Terraform state, `.tfvars`, local env files, IAM access keys, or secret values.
- `autoinstall-os/preseed.cfg` contains an `ops` password hash and an SSH public key; treat the repo as private.
- Kubernetes app manifests, External Secrets manifests, Velero manifests, NVIDIA GPU Operator, and NVIDIA device plugin belong in GitOps/Argo CD, not this repo.

## Terraform AWS

- Run Terraform from `terraform/aws/`.
- Validate with `terraform fmt -check -recursive` and `terraform validate`.
- Terraform state uses the S3 backend bucket `homelab-tf-state-rubenspensky`, key `infra/aws/terraform.tfstate`, and S3 native `use_lockfile = true`; do not add DynamoDB locking.
- Defaults are `aws_region = "us-east-2"`, `name_prefix = "homelab"`, and backup expiration after `180` days.
- Managed secrets are only containers: `homelab/cloudflare/tunnel-token` and `homelab/github/arc-app`; put values with `aws secretsmanager put-secret-value`, not Terraform.
- IAM users are `homelab-s3-backups` and `homelab-secrets-reader`; create access keys manually with `aws iam create-access-key` so keys do not land in Terraform state.
- The backups bucket name is `homelab-backups-<aws-account-id>` and has versioning, SSE-S3 encryption, public access blocking, and lifecycle expiration.

## Ansible

- Run Ansible commands from `ansible/`; `ansible.cfg` sets `inventory = inventories/lab/hosts.ini`, `roles_path = roles`, and `remote_user = ops`.
- Validate syntax with `ansible-playbook site.yaml --syntax-check` and `ansible-playbook playbooks/cluster-addons.yaml --syntax-check`.
- Use `--limit` for focused runs, e.g. `ansible-playbook site.yaml --limit k8s-worker-02` or `ansible-playbook site.yaml --limit k8s-control-01`.
- Main lab inventory: `k8s-control-01` is `192.168.0.110`, `k8s-worker-01` is `192.168.0.111`, and `k8s-worker-02` is `192.168.0.112`.
- `site.yaml` order matters: base, laptop config, NVIDIA host config, Kubernetes common, control plane, workers.
- A special test inventory treats `k8s-worker-02` as a temporary single-node control plane: `ansible-playbook -i inventories/test-worker2-control-plane/hosts.ini site.yaml`.
- Do not reuse a node initialized with `kubeadm init` as a normal worker without resetting Kubernetes first.

## Kubernetes Bootstrap

- Kubernetes repo version is `v1.36`; cluster vars live under `ansible/inventories/*/group_vars/k8s_cluster.yaml`.
- Cilium is installed during bootstrap because the cluster needs a CNI before normal pods are usable.
- Argo CD is separate from `site.yaml`; install it with `ansible-playbook playbooks/cluster-addons.yaml`.
- For the single-node test cluster, install addons with `ansible-playbook -i inventories/test-worker2-control-plane/hosts.ini playbooks/cluster-addons.yaml`.
- Argo CD is exposed as `ClusterIP`; access with `kubectl -n argocd port-forward svc/argocd-server 8080:443`.

## Containerd Gotchas

- Debian's default `containerd` config caused `kube-apiserver` crashes during testing; keep Kubernetes 1.36 settings explicit in `roles/containerd`.
- Required containerd settings: `SystemdCgroup = true`, `sandbox_image = "registry.k8s.io/pause:3.10.2"`, and CNI `bin_dir = "/opt/cni/bin"`.
- If CoreDNS is stuck in `ContainerCreating`, check events for missing `cilium-cni` or `loopback`; that usually means containerd is using the wrong CNI path.

## NVIDIA GPU

- NVIDIA support in Ansible is host/runtime only; do not install NVIDIA GPU Operator or the NVIDIA device plugin here.
- GPU node vars live in `ansible/inventories/lab/group_vars/gpu.yaml` and `ansible/inventories/lab/host_vars/k8s-control-01.yaml`.
- The GPU target is a GTX 1060 6GB on Debian 13.
- After first installing `nvidia-driver`, a reboot may be required before `nvidia-smi` works.
- Validate host/runtime with `nvidia-smi` and `containerd config dump | grep -E 'default_runtime_name|nvidia-container-runtime|SystemdCgroup'`.

## Autoinstall ISO

- Build from `autoinstall-os/` with `./build-iso.sh`; the script does not download Debian and does not write USB drives.
- Put a Debian amd64 netinst ISO next to `build-iso.sh` or pass it explicitly: `./build-iso.sh /path/to/debian-13.5.0-amd64-netinst.iso`.
- Output is `autoinstall-os/dist/debian-autoinstall-ops.iso` and must stay untracked.
- The build refuses to run if `preseed.cfg` still contains `REPLACE_WITH_SHA512_CRYPT_HASH`.
