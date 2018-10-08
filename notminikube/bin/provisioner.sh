#!/usr/bin/env bash
THISHOME="/home/vagrant"

update() {
  echo "################## update "
  echo "- Refresh package list"
  sudo apt-get update && \
  sudo apt-get -y upgrade && \
  sudo apt-get install -y \
  curl
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

kubectl() {
  echo "################## kubectl "
  wget --quiet "https://storage.googleapis.com/kubernetes-release/release/v1.10.1/bin/linux/amd64/kubectl" 2>/dev/null
  echo "Downloaded"
  sudo chmod +x kubectl
  sudo mv kubectl /usr/local/bin
  echo "Moved"
  kubectl version
  echo "tested"
}

haproxy() {
  echo "################## haproxy "
  sudo apt-get install -y haproxy
  sudo cp $THISHOME/files/haproxy.cfg /etc/haproxy/haproxy.cfg
  sudo systemctl restart haproxy
}

tls() {
  echo "################## TLS "
  cfssl gencert -initca $THISHOME/files/ca-csr.json | cfssljson -bare ca
  ls -la 
  cfssl gencert \
    -ca=ca.pem \
    -ca-key=ca-key.pem \
    -config=$THISHOME/files/ca-config.json \
    -hostname=10.10.40.90,127.0.0.1,kubernetes.default \
    -profile=kubernetes kubernetes-csr.json | \
    cfssljson -bare kubernetes
  ls -la
  #scp ca.pem kubernetes.pem kubernetes-key.pem sguyennet@10.10.40.90:~
}

testfile(){
  echo "#########################################################"
  echo "######### TEST"
  chmod +x $THISHOME/files/test.sh
  $THISHOME/files/test.sh
}

update
ssl
kubectl
haproxy
tls
testfile
