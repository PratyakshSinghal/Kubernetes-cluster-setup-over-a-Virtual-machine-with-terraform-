#!/bin/bash

# Exit on error
set -e

# Check if kubeadm is already installed
if command -v kubeadm &> /dev/null; then
  echo "kubeadm is already installed. Exiting script."
  exit 0
fi

echo "kubeadm not found. Proceeding with installation..."

# Logging functions
log_success() {
  echo "✔ SUCCESS: $1"
}

log_error() {
  echo "✖ ERROR: $1" >&2
  exit 1
}

# Disable swap
swapoff -a && log_success "Disabled swap" || log_error "Failed to disable swap"

# Update system
apt-get update && log_success "System updated" || log_error "Failed to update system"

# Install dependencies
apt-get install -y apt-transport-https ca-certificates curl gpg && log_success "Installed dependencies" || log_error "Failed to install dependencies"

# Setup Kubernetes repo
mkdir -p /etc/apt/keyrings/
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && log_success "Kubernetes key added" || log_error "Failed to add Kubernetes key"

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list && log_success "Kubernetes repository added" || log_error "Failed to add Kubernetes repository"

# Update after adding Kubernetes repo
sleep 5
apt-get update && log_success "Updated system after adding Kubernetes repo" || log_error "Failed to update system"

# Install kubelet and kubeadm
sleep 5
apt install -y kubelet kubeadm && log_success "Installed kubelet and kubeadm" || log_error "Failed to install kubelet and kubeadm"

# Hold kubelet and kubeadm versions
sleep 5
apt-mark hold kubelet kubeadm && log_success "Held kubelet and kubeadm versions" || log_error "Failed to hold kubelet and kubeadm"

# Configure sysctl
modprobe br_netfilter
echo 'br_netfilter' | tee /etc/modules-load.d/k8s.conf

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system && log_success "Applied sysctl settings" || log_error "Failed to apply sysctl settings"

# Display values
sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward

# Install container runtime: containerd

# Install containerd
wget https://github.com/containerd/containerd/releases/download/v2.1.3/containerd-2.1.3-linux-amd64.tar.gz
tar -C /usr/local -xzf containerd-2.1.3-linux-amd64.tar.gz

# Install runc
wget https://github.com/opencontainers/runc/releases/download/v1.3.0/runc.amd64
install -m 755 runc.amd64 /usr/local/sbin/runc

# Install CNI plugins
wget https://github.com/containernetworking/plugins/releases/download/v1.7.1/cni-plugins-linux-amd64-v1.7.1.tgz
mkdir -p /opt/cni/bin
tar -C /opt/cni/bin -xzf cni-plugins-linux-amd64-v1.7.1.tgz

# Setup containerd systemd service
wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
mkdir -p /usr/local/lib/systemd/system
cp containerd.service /usr/local/lib/systemd/system/

systemctl daemon-reload
systemctl enable --now containerd

# Reapply sysctl settings
modprobe br_netfilter && log_success "Loaded br_netfilter module" || log_error "Failed to load br_netfilter module"
sysctl --system && log_success "Reapplied sysctl settings" || log_error "Failed to reapply sysctl settings"

# Join reminder
echo "⚠ Reminder: Run 'kubeadm token create --print-join-command' on the master node and execute the output on this worker node."
