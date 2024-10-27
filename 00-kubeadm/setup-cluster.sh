#!/bin/bash

# Get the version numbers from environment variables
CONTAINERD_VERSION=${CONTAINERD_VERSION:-"1.7.23"}
RUNC_VERSION=${RUNC_VERSION:-"1.2.0"}
CNI_PLUGINS_VERSION=${CNI_PLUGINS_VERSION:-"1.6.0"}
KUBERNETES_VERSION=${KUBERNETES_VERSION:-"1.31"}
IS_CONTROL_PLANE=${IS_CONTROL_PLANE:-"false"}

# Environment variables for apt upgrade
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

# Open the necessary ports
sudo ufw allow proto tcp from any to any port 6443,2379,2380,10250,10257,10259,179

# Install initial dependencies
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl

# Turn off swap
sudo swapoff -a
sudo sed -i '/^\/swap\.img/s/^/#/' /etc/fstab

#Enable IP tables to bridge traffic on all nodes
# https://kubernetes.io/docs/setup/production-environment/container-runtimes/#forwarding-ipv4-and-letting-iptables-see-bridged-traffic
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

# Install containerd
curl -Lo /tmp/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz \
         https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz
sudo tar Cxzvf /usr/local /tmp/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz

# Install runc
curl -Lo /tmp/runc.amd64 https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/runc.amd64
sudo install -m 755 /tmp/runc.amd64 /usr/local/sbin/runc

# clean up containerd and runc files
rm -rf /tmp/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz /tmp/runc.amd64

# install containerd config
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo curl -Lo /etc/systemd/system/containerd.service https://raw.githubusercontent.com/containerd/cri/master/contrib/systemd-units/containerd.service  
sudo systemctl daemon-reload
sudo systemctl enable --now containerd
sudo systemctl status containerd --no-pager

# Install CNI plugins
curl -Lo /tmp/cni-plugins-amd64-v${CNI_PLUGINS_VERSION}.tgz \
         https://github.com/containernetworking/plugins/releases/download/v${CNI_PLUGINS_VERSION}/cni-plugins-linux-amd64-v${CNI_PLUGINS_VERSION}.tgz
sudo mkdir -p /opt/cni/bin
sudo tar Cxzvf /opt/cni/bin /tmp/cni-plugins-amd64-v${CNI_PLUGINS_VERSION}.tgz

# clean up CNI plugins
rm -rf /tmp/cni-plugins-amd64-v${CNI_PLUGINS_VERSION}.tgz

# Install kubeadm, kubectl, and kubelet
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# If the directory `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
# sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VERSION}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VERSION}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Create a cluster using kubeadm - Run only on CP1
if [ x"$IS_CONTROL_PLANE" = true ]; then
   NODENAME=$(hostname -s)
   IPADDR=$(hostname -I)
   APISERVER=$(hostname -s)
   POD_NET="10.244.0.0/16"

   sudo kubeadm init --apiserver-advertise-address=$IPADDR \
                    --apiserver-cert-extra-sans=$APISERVER \
                    --pod-network-cidr=$POD_NET \
                    --node-name $NODENAME


   # Set up kube config for kubectl
   mkdir -p $HOME/.kube
   cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
   chown $(id -u):$(id -g) $HOME/.kube/config

   # Install Calico Operator
   curl -Lo /tmp/tigera-operator.yaml https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/tigera-operator.yaml
   sudo kubectl create -f /tmp/tigera-operator.yaml

   curl -Lo /tmp/custom-resources.yaml https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/custom-resources.yaml

   sed -i "s|192.168.0.0/16|$POD_NET|" /tmp/custom-resources.yaml
   sudo kubectl create -f /tmp/custom-resources.yaml

   sudo apt install bash-completion
   source /usr/share/bash-completion/bash_completion
   echo 'source <(kubectl completion bash)' >>~/.bashrc
   echo 'alias k=kubectl' >>~/.bashrc
   echo 'complete -o default -F __start_kubectl k' >>~/.bashrc
fi

# Join remaining nodes
#sudo kubeadm join 172.16.1.11:6443 --token pydkjw.imeezbjjf8khdhmx --discovery-token-ca-cert-hash sha256:0ed7f52a91274fd5c94c3759400fe6c23c91deb299cb05fc57dbd706525d135a