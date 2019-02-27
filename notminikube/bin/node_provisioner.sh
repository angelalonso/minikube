#!/usr/bin/env bash
#TODO:
# remove authorized_keys from root user
# clean up inconsistency between use of root and sudo everywhere
VAGRANTHOME="/home/vagrant"

export DEBIAN_FRONTEND=noninteractive
CLUSTERCIDR="10.30.0.0/24"
HAPROXYIP="10.10.40.11"
THISNODE=$(hostname | sed 's/node//g')
NODEIP=$(echo "10.10.40.2"$THISNODE)

echo "##############################"
echo $NODEIP
echo "##############################"

K8SV="1.10.6"
CALICOV="3.2"

get_ssh() {
  # You should run:
  # ssh-keygen -t rsa -b 4096 -C "your_email@example.com" -f notminikube
  echo "Getting our keys on the host"
  mkdir -p $VAGRANTHOME/.ssh
  mv $VAGRANTHOME/files/notminikube.pem $VAGRANTHOME/.ssh/id_rsa
  cat $VAGRANTHOME/files/notminikube.pub >> $VAGRANTHOME/.ssh/authorized_keys
  su -l vagrant -c 'sudo chown -R $(id -u):$(id -g) /home/vagrant/.ssh'
  sudo mkdir -p /root/.ssh
  sudo sh -c "cat $VAGRANTHOME/files/notminikube.pub > /root/.ssh/authorized_keys"
}

update() {
  echo "################## update "
  echo "- Refresh package list"
  # the overcomplicated apt-get upgrade comes from a grub update that messes with the noninteractive nature of this script
  sudo apt-get update && \
  sudo DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade && \
  sudo apt-get -y upgrade 
  sudo apt-get install -y \
  apt-transport-https \
  curl \
  chrony \
  net-tools \
  software-properties-common \
  vim
}

ssl() {
  # Based on https://blog.inkubate.io/install-and-configure-a-multi-node-kubernetes-cluster-with-kubeadm/
  echo "################## SSL "
  wget --quiet https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 2>/dev/null
  wget --quiet https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64 2>/dev/null
  chmod +x cfssl*
  sudo mv cfssl_linux-amd64 /usr/local/bin/cfssl
  sudo mv cfssljson_linux-amd64 /usr/local/bin/cfssljson
  cfssl version
}

get_kubectl() {
  echo "################## kubectl "
  wget --quiet "https://storage.googleapis.com/kubernetes-release/release/v1.10.1/bin/linux/amd64/kubectl" 2>/dev/null
  sudo chmod +x kubectl
  sudo mv kubectl /usr/local/bin
  kubectl version 2>/dev/null # This will fail because there's nothing on port 8080 yet...
}

tls() {
  echo "################## TLS "
  echo "# Copying CERTS"
  ls -lha
  scp -o 'StrictHostKeyChecking no' -i $VAGRANTHOME/.ssh/id_rsa root@10.10.40.11:$VAGRANTHOME/*.pem $VAGRANTHOME
  ls -lha

  #scp ca.pem kubernetes.pem kubernetes-key.pem sguyennet@10.10.40.90:~
}

get_docker() {
  echo "################## Docker "
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository \
    "deb https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") \
    $(lsb_release -cs) \
    stable"
  sudo apt-get update
  sudo apt-get install -y docker-ce=$(apt-cache madison docker-ce | grep 17.03 | head -1 | awk '{print $3}')
  sudo docker version
}

get_kubethings() {
  echo "################## Kubeadm, Kubelet, Kubectl"
  sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
  sudo sh -c 'echo "deb http://apt.kubernetes.io kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list'
  sudo apt-get update
  sudo apt-get install -y kubelet=$K8SV-00 kubeadm=$K8SV-00 kubectl=$K8SV-00 --allow-downgrades
  swapoff -a
  sed -i '/ swap / s/^/#/' /etc/fstab

}

init_node() {
  # We need to do this ONLY when all three nodes on ETCD are up and running.
  #  therefore, I only call node1 and node2 when all three nodes are done.
  echo "Doing node"$THISNODE" !"
  CMD=$(ssh -o 'StrictHostKeyChecking no' -i /home/vagrant/.ssh/id_rsa root@10.10.40.11 "kubeadm token create --print-join-command")
  kubeadm reset
  $CMD --ignore-preflight-errors=CRI
  # We need to give the cluster some time to have the new node ready
  echo "waiting 20 secs"
  sleep 20 
  ssh -o 'StrictHostKeyChecking no' -i /home/vagrant/.ssh/id_rsa vagrant@10.10.40.11 "kubectl label node node$THISNODE node-role.kubernetes.io/node="
}

get_ssh
update
ssl
get_kubectl
tls
get_docker
get_kubethings
init_node
