#!/usr/bin/env bash
THISHOME="/home/vagrant"

update() {
  echo "- Refresh package list"
  sudo apt-get update && \
  sudo apt-get -y upgrade && \
  sudo apt-get install \
  curl
}

ssl() {
  # Based on https://blog.inkubate.io/install-and-configure-a-multi-master-kubernetes-cluster-with-kubeadm/
  wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
  wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
  chmod +x cfssl*
  sudo mv cfssl_linux-amd64 /usr/local/bin/cfssl
  sudo mv cfssljson_linux-amd64 /usr/local/bin/cfssljson
  cfssl version
}

kubectl() {
  wget https://storage.googleapis.com/kubernetes-release/release/v1.10.1/bin/linux/amd64/kubectl
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin
  kubectl version
}

haproxy() {
  sudo apt-get install -y haproxy
}

testfile(){
  echo "######### TEST"
  chmod +x $THISHOME/files/test.sh
  $THISHOME/files/test.sh
}

#update
#ssl
#kubectl
#haproxy
testfile
