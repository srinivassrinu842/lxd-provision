# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  config.vm.box = "ubuntu/bionic64"
  config.vm.box_check_update = false

  config.vm.network "private_network", ip: '192.168.56.51', :name => 'VirtualBox Host-Only Ethernet Adapter', :adapter => 2

  config.vm.provider "virtualbox" do |vb|
    vb.name = "master"
    vb.cpus = 4
    vb.memory = "6144"
  end

  config.vm.provision "shell", inline: <<-SHELL
    sed -i '/swap/d' /etc/fstab
    swapoff -a
	
    systemctl disable --now ufw >/dev/null 2>&1

    echo "overlay" >> /etc/modules-load.d/containerd.conf
    echo "br_netfilter" >> /etc/modules-load.d/containerd.conf

    modprobe overlay
    modprobe br_netfilter
	
    echo "net.bridge.bridge-nf-call-ip6tables = 1" >> /etc/sysctl.d/kubernetes.conf
    echo "net.bridge.bridge-nf-call-iptables  = 1" >> /etc/sysctl.d/kubernetes.conf
    echo "net.ipv4.ip_forward                 = 1" >> /etc/sysctl.d/kubernetes.conf

    sysctl --system >/dev/null 2>&1
	
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - >/dev/null 2>&1
    apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main" >/dev/null 2>&1
    apt install -qq -y kubectl >/dev/null 2>&1
	
    useradd kadmin
    echo -e "kubeadmin\nkubeadmin" | passwd kadmin >/dev/null 2>&1
    echo -e "kubeadmin\nkubeadmin" | passwd root >/dev/null 2>&1
    echo "export TERM=xterm" >> /etc/bash.bashrc

    sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
    systemctl reload sshd
	
	gpasswd -a vagrant lxd
	gpasswd -a kadmin lxd
	
	systemctl enable --now lxd
  SHELL
end
