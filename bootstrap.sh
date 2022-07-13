#!/bin/bash

# This script has been tested on Centos 7

echo "[TASK 1] Install CRIO"
VERSION=1.22
curl -L -o /etc/yum.repos.d/devel:kubic:libcontainers:stable.repo https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable/CentOS_7/devel:kubic:libcontainers:stable.repo
curl -L -o /etc/yum.repos.d/devel:kubic:libcontainers:stable:cri-o:${VERSION}.repo https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:${VERSION}/CentOS_7/devel:kubic:libcontainers:stable:cri-o:${VERSION}.repo

echo "[TASK 2] Install Kubernetes repository"
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

echo "[TASK 3] Install crio kubelet kubeadm kubectl"
yum install -y yum-utils
yum install -y cri-o cri-tools kubelet kubeadm kubectl net-tools 

echo "[TASK 4] Kubelet configuration"
echo 'KUBELET_EXTRA_ARGS="--fail-swap-on=false"' > /etc/default/kubelet
echo 'L /dev/kmsg - - - - /dev/console' > /etc/tmpfiles.d/kmsg.conf

echo "[TASK 5] Start and enable CRIO & Kubelet services"
systemctl daemon-reload
systemctl enable --now crio
systemctl enable --now kubelet

echo "[TASK 5.1] Enable ssh password authentication"
sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
systemctl reload sshd

echo "[TASK 5.2] Set root password"
echo -e "kubeadmin\nkubeadmin" | passwd root >/dev/null 2>&1

echo "[TASK 6] mount /sys as shared filesystem"
mount --make-shared /sys

#######################################
# To be executed only on master nodes #
#######################################

if [[ $(hostname) =~ .*master.* ]]
then
   echo "[TASK 7] Pull required containers"
   kubeadm config images pull

   echo "[TASK 8] Initialize Kubernetes Cluster"
   #kubeadm init --apiserver-advertise-address=10.108.204.84 --pod-network-cidr=192.168.0.0/16 --ignore-preflight-errors=all
   kubeadm init --pod-network-cidr=192.168.0.0/16 --ignore-preflight-errors=all >> /root/kubeinit.log 2>&1
   
   echo "[TASK 9] Copy kube admin config to root user .kube directory"
   mkdir /root/.kube
   cp /etc/kubernetes/admin.conf /root/.kube/config  

   echo "[TASK 10] Deploy Calico network"
   kubectl --kubeconfig=/etc/kubernetes/admin.conf create -f https://docs.projectcalico.org/v3.18/manifests/calico.yaml

   echo "[TASK 11] Generate and save cluster join command to /joincluster.sh"
   joinCommand=$(kubeadm token create --print-join-command 2>/dev/null) 
   echo "$joinCommand --ignore-preflight-errors=all" > /joincluster.sh

fi

#######################################
# To be executed only on worker nodes #
#######################################

if [[ $(hostname) =~ .*worker.* ]]
then
  echo "[TASK 7] Join node to Kubernetes Cluster"
  yum install -y sshpass >/dev/null 2>&1
  sshpass -p "kubeadmin" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no kmaster.lxd:/joincluster.sh /joincluster.sh 2>/tmp/joincluster.log
  bash /joincluster.sh >> /tmp/joincluster.log 2>&1
fi