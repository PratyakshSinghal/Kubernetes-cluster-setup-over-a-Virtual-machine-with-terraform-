
# ☸️ K8s  Deployment — Prerequisites & Setup Guide

This guide outlines the system layout, configuration requirements, and setup instructions for automating the deployment of a **Kubernetes cluster**  using Terraform and shell scripts.
The interface changes referenced in this setup (e.g., eth0, eth1) are specific to the Open5GS 5G Core network configuration. These mappings facilitate data-plane and control-plane segregation for accurate emulation of telecom network behavior.

However, if your goal is solely to set up a Kubernetes cluster (without deploying Open5GS), you may skip renaming or reassigning network interfaces. The default interface names assigned by your cloud provider or OS (such as ens3, eth0, enp0s8, etc.) will work fine for basic K8s functionality.

✅ This simplification helps reduce setup complexity and avoids the need for manual udev rules or interface remapping during early experimentation.


---

## 🚀 Prerequisites

Before starting, ensure all the conditions below are met:

---

## ☁️ VM Configuration

Your **Google Cloud Platform Virtual Machines** should be provisioned with the following **exact configuration** to ensure compatibility:

### 🧩 Boot Disk

| Property            | Value                          |
|---------------------|-------------------------------|
| **Boot Disk Image** | `ubuntu-2204-jammy-v20250722` |
| **Architecture**    | `x86_64`                       |

---

### 🌐 Network Interfaces

Each VM must have **two NICs** configured:

| Interface | Network             | Subnetwork           | Internal IP      | External IP | IP Stack | IP Forwarding |
|-----------|----------------------|----------------------|------------------|-------------|----------|----------------|
| `nic0`    | `mgmt-network`       | `mgmt-subnet`        | Auto-assigned    | None        | IPv4     | ❌ Off          |
| `nic1`    | `data-plane-network` | `data-plane-subnet`  | Auto-assigned    | None        | IPv4     | ❌ Off          |

- `eth0` (mapped from `nic0`): Used for Kubernetes control-plane + Open5GS signaling  
- `eth1` (mapped from `nic1`): Used for Open5GS **data-plane** (e.g., UPF N6 interface)

⚠️ **Ensure IP forwarding is disabled on both interfaces.**

---

### 🔌 Interface Status

Both `eth0` and `eth1` must:

- Be **up and active** (`ip a` or `ifconfig`)
- Have **assigned IPs**
- Be **reachable across nodes** (ping test)

---

## 🔐 Network & Node Access Requirements

- **Passwordless SSH access** must be enabled from the master node to the worker node.
- Use **private key authentication** (`~/.ssh/id_rsa`).
- Each node should be accessible from the others using their IPs.

---

## 🧱 Interface Configuration Summary

| Node Type     | Interface | Purpose                        |
|---------------|-----------|--------------------------------|
| Master/Worker | `eth0`    | Kubernetes control-plane + 5GC |
| Master/Worker | `eth1`    | N6 interface (data path)       |

---

## 📁 Required Files & Folder Structure

Ensure the working directory (usually the **home directory** of the master node user) includes the following:

```
├── master_node.sh              # Sets up Kubernetes master
├── worker_node.sh              # Joins worker node to cluster
└── terraform/                  # Infra provisioning setup
    ├── main.tf                 # Terraform infra logic
    └── variable.tf             # SSH IPs, keys, and script paths
```

---

## 🔓 Script Permissions

Make sure shell scripts are executable:

```bash
chmod +x master_node.sh worker_node.sh 
```

Ensure Terraform scripts using `local-exec` have proper execution permissions and accessible paths.

---

## 🔑 SSH Private Key Path Configuration

### Check if you already have an SSH key:

```bash
ls ~/.ssh/id_rsa
```

If it exists, specify the path in `variable.tf` like:

```hcl
private_key_path = "/home/<your-username>/.ssh/id_rsa"
```

---

## ✏️ Editing `variable.tf`

Update these variables as needed:

| Variable Name         | Description                            |
|------------------------|----------------------------------------|
| `master_ip`           | IP of the Kubernetes master node        |
| `worker_ip`           | IP of the worker node                   |
| `ssh_user`            | Username used for SSH                   |
| `private_key_path`    | Path to your SSH private key            |
| `master_script_path`  | Full path to `master_node.sh`           |
| `worker_script_path`  | Full path to `worker_node.sh`           |


### Modify in terminal:

```bash
cd terraform
nano variable.tf
# Ctrl + O to save, Ctrl + X to exit
```

---

## 🛠 Terraform Setup

From within the `terraform/` directory:

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

This will:

- Spin up the required **GCP instances**
- Configure **Kubernetes** master and worker nodes


---

## ✅ Verify Setup

Once complete, confirm pods are running with:

```bash
kubectl get pods -A -o wide
```

---

## 📌 Notes

- Test node-to-node communication with `ping <IP>`
- Verify `eth0`/`eth1` mapping using `ip a`
- Ensure all scripts are executable and paths in `variable.tf` are correct

---

Feel free to [raise an issue](#) or open a pull request for any improvements or troubleshooting!
