#!/usr/bin/env bash
THISHOME="/home/vagrant"

export DEBIAN_FRONTEND=noninteractive
MASTER1IP="10.0.2.15"

update() {
  echo "################## update "
  echo "- Refresh package list"
  sudo apt-get update && \
  sudo apt-get -y upgrade && \
  sudo apt-get install -y \
  apt-transport-https \
  curl \
  software-properties-common
}

ssl() {
  # Based on https://blog.inkubate.io/install-and-configure-a-multi-master-kubernetes-cluster-with-kubeadm/
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

get_haproxy() {
  echo "################## haproxy "
  sudo apt-get install -y haproxy
  sudo sed 's/xx.xx.xx.xx/10.0.2.15/g' $THISHOME/files/haproxy.cfg > /etc/haproxy/haproxy.cfg
  sudo systemctl restart haproxy
}

tls() {
  echo "################## TLS "
  echo "## Certificate Authority"
  cfssl gencert -initca $THISHOME/files/ca-csr.json | cfssljson -bare ca
  ls -la 
  echo "## Etcd Cluster"
  cfssl gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config=$THISHOME/files/ca-config.json \
    -hostname=$MASTER1IP,127.0.0.1,kubernetes.default \
    -profile=kubernetes $THISHOME/files/kubernetes-csr.json | \
    cfssljson -bare kubernetes
  ls -la
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
  sudo apt-get install -y kubelet kubeadm kubectl
  swapoff -a
  sed -i '/ swap / s/^/#/' /etc/fstab

}

testfile(){
  echo "#########################################################"
  echo "######### TEST"
  chmod +x $THISHOME/files/test.sh
  $THISHOME/files/test.sh
}

update
ssl
get_kubectl
get_haproxy
tls
get_docker
get_kubethings
testfile
