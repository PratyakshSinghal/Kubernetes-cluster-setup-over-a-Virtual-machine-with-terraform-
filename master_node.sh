#!/bin/bash

set -e  # Exit on error

# Logging functions
log_success() {
    echo "✔ SUCCESS: $1"
}

log_error() {
    echo "❌ ERROR: $1" >&2
    exit 1
}

# Exit if containerd is already installed
if command -v containerd >/dev/null 2>&1; then
    echo "containerd is already installed. Exiting setup script."
    exit 0
fi

# Disable swap
swapoff -a && log_success "Swap disabled" || log_error "Failed to disable swap"

# Update package lists
apt-get update && log_success "System updated" || log_error "Failed to update system"

# Install dependencies
apt-get install -y apt-transport-https ca-certificates curl gpg && log_success "Dependencies installed" || log_error "Failed to install dependencies"

# Add Kubernetes repository
mkdir -p /etc/apt/keyrings/
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && log_success "Kubernetes key added" || log_error "Failed to add Kubernetes key"

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list && log_success "Kubernetes repository added" || log_error "Failed to add Kubernetes repository"

sleep 10
apt-get update && log_success "Updated package lists after adding Kubernetes repo" || log_error "Failed to update package lists"
sleep 5

# Install Kubernetes components
apt install -y kubelet kubeadm kubectl && log_success "Kubernetes components installed" || log_error "Failed to install Kubernetes components"
sleep 5
apt-mark hold kubelet kubeadm kubectl && log_success "Marked Kubernetes components to hold updates" || log_error "Failed to mark Kubernetes components"

# Kernel modules and sysctl settings
modprobe br_netfilter
echo 'br_netfilter' | tee /etc/modules-load.d/k8s.conf

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system && log_success "Applied sysctl settings" || log_error "Failed to apply sysctl settings"

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

# Configure containerd systemd service
wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
mkdir -p /usr/local/lib/systemd/system
cp containerd.service /usr/local/lib/systemd/system/

systemctl daemon-reload
systemctl enable --now containerd

sysctl --system && log_success "Re-applied sysctl settings" || log_error "Failed to re-apply sysctl settings"
modprobe br_netfilter && log_success "Loaded br_netfilter module" || log_error "Failed to load br_netfilter module"

# Initialize Kubernetes cluster
kubeadm init --pod-network-cidr=10.244.0.0/16

# Configure kubectl access
sleep 30
echo "Checking if $HOME/.kube/config exists..."

if [ ! -f "$HOME/.kube/config" ]; then
    echo "File not found: $HOME/.kube/config. Creating and copying admin.conf..."
    mkdir -p "$HOME/.kube"
    cp /etc/kubernetes/admin.conf "$HOME/.kube/config"
    chown $(id -u):$(id -g) "$HOME/.kube/config"
    echo "Config copied and ownership changed."
else
    echo "File $HOME/.kube/config already exists. Skipping copy."
fi

sleep 30
echo "✅ Kubernetes master setup completed successfully! Now applying Flannel CNI plugin..."

# Apply Flannel CNI
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

sleep 50
