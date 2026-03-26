#!/bin/bash

set -e

echo "🚀 Starting Kubernetes (kubeadm) setup on Amazon Linux..."

# -----------------------------
# 1. Disable swap
# -----------------------------
echo "🔧 Disabling swap..."
sudo swapoff -a
sudo sed -i '/swap/d' /etc/fstab

# -----------------------------
# 2. Kernel modules
# -----------------------------
echo "🔧 Configuring kernel modules..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# -----------------------------
# 3. Sysctl settings
# -----------------------------
echo "🔧 Applying sysctl params..."
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

# -----------------------------
# 4. Install containerd
# -----------------------------
echo "📦 Installing containerd..."
sudo yum install -y containerd

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

# Enable systemd cgroup
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd

# -----------------------------
# 5. Add Kubernetes repo
# -----------------------------
echo "📦 Adding Kubernetes repo..."

cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key
EOF

# -----------------------------
# 6. Install kubeadm, kubelet, kubectl
# -----------------------------
echo "📦 Installing kubeadm, kubelet, kubectl..."
sudo yum install -y kubelet kubeadm kubectl

sudo systemctl enable kubelet

# -----------------------------
# 7. Start services
# -----------------------------
echo "🚀 Starting services..."
sudo systemctl daemon-reexec
sudo systemctl restart kubelet

echo "✅ Installation complete!"
echo ""
echo "👉 Next step:"
echo "   Run: sudo kubeadm init"

sudo kubeadm init

rm -rf /home/ec2-user/.kube/config
mkdir -p /home/ec2-user/.kube
sudo cp /etc/kubernetes/admin.conf /home/ec2-user/.kube/config

sudo chown ec2-user:ec2-user /home/ec2-user/.kube/config

kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml