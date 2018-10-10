#!/usr/bin/env bash
#TODO:
# test kubeadm from scratch
# change 10.0.2.15 on sed to use MASTER1IP instead
THISHOME="/home/vagrant"

export DEBIAN_FRONTEND=noninteractive
HAPROXYIP="10.0.2.15"
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
  sudo sed -i 's/ww.ww.ww.ww/10.0.2.15/g' $THISHOME/files/haproxy.cfg
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

get_etcd() {
  echo "################## Etcd"
  sudo mkdir -p /etc/etcd /var/lib/etcd
  sudo mv $THISHOME/ca.pem $THISHOME/kubernetes.pem $THISHOME/kubernetes-key.pem /etc/etcd
  wget --quiet https://github.com/coreos/etcd/releases/download/v3.3.9/etcd-v3.3.9-linux-amd64.tar.gz 2>/dev/null
  sleep 1
  tar xvzf etcd-v3.3.9-linux-amd64.tar.gz
  sudo mv etcd-v3.3.9-linux-amd64/etcd* /usr/local/bin/
  sudo sed 's/xx.xx.xx.xx/10.0.2.15/g' $THISHOME/files/etcd.service > /etc/systemd/system/etcd.service
  sudo systemctl daemon-reload
  sudo systemctl enable etcd
  sudo systemctl start etcd
  sleep 10
  sudo systemctl status etcd --no-pager
}

init_master() {
  echo "################## Initializing Master"
  sudo sed -i 's/ww.ww.ww.ww/10.0.2.15/g' $THISHOME/files/kubeadm_config.yaml 
  sudo sed -i 's/xx.xx.xx.xx/10.0.2.15/g' $THISHOME/files/kubeadm_config.yaml 
  sudo systemctl stop etcd
  sudo rm -rf /var/lib/etcd/member
  sudo kubeadm init --config=$THISHOME/files/kubeadm_config.yaml
  #sudo scp -r /etc/kubernetes/pki sguyennet@10.10.40.91:~
  su -l vagrant -c 'mkdir -p $HOME/.kube'
  su -l vagrant -c 'sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config'
  su -l vagrant -c 'sudo chown $(id -u):$(id -g) $HOME/.kube/config'
  echo "DID SOME OTHER THINGS...see comments on script"
  # modify endpoints to use port 6444 of haproxy
  # install calico
  #   kubectl apply -f https://docs.projectcalico.org/v3.1/getting-started/kubernetes/installation/hosted/rbac-kdd.yaml
  #   kubectl apply -f https://docs.projectcalico.org/v3.1/getting-started/kubernetes/installation/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml
  #...some other things

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
get_etcd
init_master
testfile
