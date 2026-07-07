# Ansible

This directory bootstraps Debian nodes for the homelab Kubernetes cluster.

## Current Scope

- Debian base configuration.
- Hostname configuration.
- Laptop power configuration so nodes keep running when the lid is closed.
- Kubernetes 1.36 installation with `kubeadm`.
- `containerd` as the container runtime.
- Cilium as the CNI.
- Helm installation.
- Argo CD installation as a separate cluster addon.
- NVIDIA driver and container runtime configuration for GPU nodes.
- Control plane HDD/SSD storage mounts for backups, static data, and fast local Kubernetes storage.

The NVIDIA device plugin is intentionally not installed by Ansible. It should be managed later through Argo CD.

## Layout

```text
ansible/
  ansible.cfg
  site.yaml
  inventories/
    lab/
      hosts.ini
      group_vars/
        all.yaml
        k8s_cluster.yaml
      host_vars/
        k8s-control-01.yaml
    test-worker2-control-plane/
      hosts.ini
      group_vars/
        all.yaml
        k8s_cluster.yaml
  playbooks/
    cluster-addons.yaml
  roles/
    common/
    hostname/
    laptop/
    k8s_prereqs/
    containerd/
    kubeadm/
    k8s_control_plane/
    nvidia_gpu/
    storage/
    helm/
    cilium/
    k8s_worker/
    argocd/
```

## Main Lab Topology

The normal lab inventory is `inventories/lab/hosts.ini`.

```text
k8s-control-01  192.168.0.110  control plane
k8s-worker-01   192.168.0.111  worker laptop
k8s-worker-02   192.168.0.112  worker laptop
```

Groups:

- `control_plane`: Kubernetes control plane node.
- `workers`: Kubernetes worker nodes.
- `laptops`: laptop-specific power settings.
- `gpu`: nodes with an NVIDIA GPU and host runtime configuration.
- `k8s_cluster`: all Kubernetes nodes.

## First Test: Only k8s-worker-02 As Worker

Use this if you only want to prepare the currently reachable laptop as a worker.

```sh
ansible-playbook site.yaml --limit k8s-worker-02 --check
```

Then run it for real:

```sh
ansible-playbook site.yaml --limit k8s-worker-02
```

This applies:

- `common`
- `hostname`
- `laptop`
- `k8s_prereqs`
- `containerd`
- `kubeadm`
- `k8s_worker`

If the real control plane is not initialized or not reachable yet, the worker join is skipped. The node will still be prepared with containerd and Kubernetes packages.

## Temporary Test: k8s-worker-02 As Control Plane

Use this if `k8s-worker-02` is the only node reachable by SSH and you want to test a single-node Kubernetes control plane first.

This uses the alternate inventory:

```text
inventories/test-worker2-control-plane/hosts.ini
```

That inventory treats `k8s-worker-02` at `192.168.0.112` as the control plane and sets:

```yaml
k8s_control_plane_endpoint: "192.168.0.112"
allow_workloads_on_control_plane: true
```

Validate first:

```sh
ansible-playbook -i inventories/test-worker2-control-plane/hosts.ini site.yaml --syntax-check
```

Dry run:

```sh
ansible-playbook -i inventories/test-worker2-control-plane/hosts.ini site.yaml --check
```

Run it:

```sh
ansible-playbook -i inventories/test-worker2-control-plane/hosts.ini site.yaml
```

This will initialize a single-node cluster on `k8s-worker-02`, install Helm, and install Cilium.

Validated result from the first test run:

```text
k8s-worker-02   Ready   control-plane   v1.36.2
```

Expected healthy `kube-system` pods:

```text
cilium-envoy
cilium-operator
cilium
coredns
etcd
kube-apiserver
kube-controller-manager
kube-proxy
kube-scheduler
```

Important: do not later reuse that same initialized node as a worker in the real three-node cluster without resetting Kubernetes first. A node that has already run `kubeadm init` is a control plane node, not a clean worker.

## Normal Full Cluster Bootstrap

After all nodes are reachable and the normal lab topology is ready:

```sh
ansible-playbook site.yaml
```

Expected flow:

1. Configure all hosts with common base settings.
2. Apply laptop power settings to the two laptop workers.
3. Configure NVIDIA host GPU support on nodes in the `gpu` group.
4. Install Kubernetes prerequisites, containerd, kubelet, kubeadm, and kubectl.
5. Mount control plane HDD/SSD storage.
6. Initialize the control plane on `k8s-control-01`.
7. Install Helm and Cilium on the control plane.
8. Join worker nodes to the cluster.

## Control Plane Storage

`k8s-control-01` storage settings live in `inventories/lab/host_vars/k8s-control-01.yaml` so the storage role does not hardcode disk IDs.

The role intentionally uses stable `/dev/disk/by-id` paths for disk selection and persistent mount identifiers for mounts:

- System disk is configured only for safety checks and must never be modified.
- HDD storage mounts the existing ext4 filesystem by UUID at `/mnt/hdd-storage` and does not format it.
- SSD storage creates one GPT partition on the configured disk ID, formats that partition as ext4 with label `ssd-storage`, and mounts it at `/mnt/ssd-storage`.

Install required Ansible collections with:

```sh
ansible-galaxy collection install -r requirements.yaml
```

Run only the control plane storage/bootstrap path with:

```sh
ansible-playbook site.yaml --limit k8s-control-01
```

## NVIDIA GPU

The control plane PC has a NVIDIA GeForce GTX 1060 6GB and is in the `gpu` inventory group:

```ini
[gpu]
k8s-control-01
```

The `nvidia_gpu` role handles only host-level GPU support:

- Enables Debian `contrib`, `non-free`, and `non-free-firmware` components.
- Installs `linux-headers-amd64`.
- Installs `firmware-misc-nonfree`.
- Installs `nvidia-driver`.
- Adds the NVIDIA container toolkit apt repository.
- Installs `nvidia-container-toolkit`.
- Verifies that `/usr/bin/nvidia-container-runtime` exists.
- Runs `nvidia-smi` as a non-fatal check.

The Ansible role does not install:

- NVIDIA GPU Operator.
- NVIDIA device plugin.
- CUDA application libraries.

The device plugin should be deployed later from the GitOps/Argo CD side.

On GPU nodes, `containerd` is configured with:

```toml
[plugins."io.containerd.grpc.v1.cri".containerd]
  default_runtime_name = "nvidia"

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia]
  runtime_type = "io.containerd.runc.v2"

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia.options]
  BinaryName = "/usr/bin/nvidia-container-runtime"
  SystemdCgroup = true
```

Run only the GPU host setup against the control plane with:

```sh
ansible-playbook site.yaml --limit k8s-control-01
```

After the NVIDIA driver is installed for the first time, a reboot may be required before `nvidia-smi` works:

```sh
sudo reboot
```

Then validate on the node:

```sh
nvidia-smi
containerd config dump | grep -E 'default_runtime_name|nvidia-container-runtime|SystemdCgroup'
```

After the device plugin is deployed by Argo CD, validate Kubernetes GPU visibility with:

```sh
kubectl get nodes -o custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu
```

## Cluster Addons

Argo CD is managed separately from the base cluster bootstrap.

After the cluster is working:

```sh
ansible-playbook playbooks/cluster-addons.yaml
```

This installs Argo CD in the `argocd` namespace with `argocd-server` as `ClusterIP`.

For the temporary single-node test inventory, run:

```sh
ansible-playbook -i inventories/test-worker2-control-plane/hosts.ini playbooks/cluster-addons.yaml
```

Expected healthy Argo CD pods:

```text
argocd-application-controller
argocd-applicationset-controller
argocd-dex-server
argocd-notifications-controller
argocd-redis
argocd-repo-server
argocd-server
```

Access it with port-forward:

```sh
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Then open:

```text
https://localhost:8080
```

Initial username:

```text
admin
```

Initial password:

```sh
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
```

If running `kubectl` on the node as `ops`, the kubeconfig is already copied to:

```text
/home/ops/.kube/config
```

## Useful Commands

List hosts affected by a limited run:

```sh
ansible-playbook site.yaml --limit k8s-worker-02 --list-hosts
```

List tasks for a limited run:

```sh
ansible-playbook site.yaml --limit k8s-worker-02 --list-tasks
```

Validate syntax:

```sh
ansible-playbook site.yaml --syntax-check
ansible-playbook playbooks/cluster-addons.yaml --syntax-check
```

Run with more output:

```sh
ansible-playbook site.yaml --limit k8s-worker-02 -v
```

Check the test control plane from Ansible:

```sh
ansible k8s-worker-02 -i inventories/test-worker2-control-plane/hosts.ini \
  -b -m command -a "kubectl --kubeconfig /etc/kubernetes/admin.conf get nodes"
```

Check all pods:

```sh
ansible k8s-worker-02 -i inventories/test-worker2-control-plane/hosts.ini \
  -b -m command -a "kubectl --kubeconfig /etc/kubernetes/admin.conf get pods -A"
```

Check listening services if the API server is not responding:

```sh
ansible k8s-worker-02 -i inventories/test-worker2-control-plane/hosts.ini \
  -b -m command -a "ss -ltnp"
```

Check containerd effective config:

```sh
ansible k8s-worker-02 -i inventories/test-worker2-control-plane/hosts.ini \
  -b -m shell -a "containerd config dump | grep -E 'sandbox_image|SystemdCgroup|bin_dir'"
```

## Troubleshooting Notes

During the first single-node test, `kubeadm init` succeeded and `kubectl get nodes` briefly worked, but then the API server started returning:

```text
The connection to the server 192.168.0.112:6443 was refused
```

The root cause was the default Debian `containerd` config. It had these wrong defaults for Kubernetes 1.36:

```text
SystemdCgroup = false
sandbox_image = "registry.k8s.io/pause:3.8"
CNI bin_dir = "/usr/lib/cni"
```

The Ansible `containerd` role now writes the required config explicitly:

```toml
version = 2

[plugins."io.containerd.grpc.v1.cri"]
  sandbox_image = "registry.k8s.io/pause:3.10.2"

[plugins."io.containerd.grpc.v1.cri".cni]
  bin_dir = "/opt/cni/bin"
  conf_dir = "/etc/cni/net.d"

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  runtime_type = "io.containerd.runc.v2"

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
  SystemdCgroup = true
```

After this fix, restarting `containerd` and `kubelet` was enough. A full node reboot was not required.

If `CoreDNS` is stuck in `ContainerCreating`, check events:

```sh
kubectl get events -A --sort-by=.lastTimestamp
```

If events mention missing `cilium-cni` or `loopback` under `/usr/lib/cni`, containerd is using the wrong CNI path. It should use `/opt/cni/bin`.

The single-node inventory also sets:

```yaml
cilium_operator_replicas: 1
```

This avoids a second Cilium operator pod staying `Pending` on a one-node cluster because of port conflicts.

Warnings like this were observed and are not currently blocking cluster health:

```text
Nameserver limits were exceeded, some nameservers have been omitted
```

That means the host has more DNS servers than Kubernetes will pass to pods. The effective list still includes the first three nameservers.

## Notes

- Kubernetes version is configured through `kubernetes_apt_repo_version` and currently uses `v1.36`.
- containerd is configured with systemd cgroups, `registry.k8s.io/pause:3.10.2`, and `/opt/cni/bin` for Kubernetes 1.36.
- GPU nodes override containerd to use the NVIDIA runtime by default.
- Cilium operator replicas are set to `1` for the current single-node bootstrap path.
- Cilium is installed during bootstrap because the cluster needs a CNI to become usable.
- Argo CD is installed later as an addon.
- NVIDIA device plugin deployment belongs to GitOps/Argo CD, not this Ansible bootstrap.
