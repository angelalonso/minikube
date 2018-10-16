#!/usr/bin/env bash
#TODO:
# remove authorized_keys from root user
# Document README.md -> creation of keys
VAGRANTHOME="/home/vagrant"

export DEBIAN_FRONTEND=noninteractive
CLUSTERCIDR="10.30.0.0/24"
HAPROXYIP="10.10.40.15"
THISMASTER=$(hostname | sed 's/master//g')
MASTERIP=$(echo "10.10.40.1"$THISMASTER)

echo "##############################"
echo $MASTERIP
echo "##############################"

K8SV="1.10.6"
CALICOV="3.0"

get_ssh() {
  # You should run:
  # ssh-keygen -t rsa -b 4096 -C "your_email@example.com" -f notminikube
  echo "Getting our keys on the host"
  mkdir -p $VAGRANTHOME/.ssh
  mv $VAGRANTHOME/files/notminikube.pem $VAGRANTHOME/.ssh/id_rsa
  cat $VAGRANTHOME/files/notminikube.pub > $VAGRANTHOME/.ssh/authorized_keys
  su -l vagrant -c 'sudo chown -R $(id -u):$(id -g) /home/vagrant/.ssh'
  sudo mkdir -p /root/.ssh
  sudo sh -c "cat $VAGRANTHOME/files/notminikube.pub > /root/.ssh/authorized_keys"
}

update() {
  echo "################## update "
  echo "- Refresh package list"
  sudo apt-get update && \
  sudo apt-get -y upgrade && \
  sudo apt-get install -y \
  apt-transport-https \
  curl \
  net-tools \
  software-properties-common \
  vim
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
  sudo sed -i "s/ww.ww.ww.ww/$MASTERIP/g" $VAGRANTHOME/files/haproxy.cfg
  sudo sed "s/xx.xx.xx.xx/$MASTERIP/g" $VAGRANTHOME/files/haproxy.cfg > /etc/haproxy/haproxy.cfg
  sudo systemctl restart haproxy
}

tls() {
  echo "################## TLS "
  if [ $THISMASTER -eq 1 ]; then
    echo "# Generating CERTS"
    echo "## Certificate Authority"
    cfssl gencert -initca $VAGRANTHOME/files/ca-csr.json | cfssljson -bare ca
    echo "## Etcd Cluster"
    cfssl gencert \
      -ca=ca.pem \
      -ca-key=ca-key.pem \
      -config=$VAGRANTHOME/files/ca-config.json \
      -hostname=10.10.40.11,10.10.40.12,10.10.40.13,10.10.40.15,127.0.0.1,kubernetes.default \
      -profile=kubernetes $VAGRANTHOME/files/kubernetes-csr.json | \
      cfssljson -bare kubernetes
  elif [ $THISMASTER -eq 2 ] || [ $THISMASTER -eq 3 ] ; then
    echo "# Copying CERTS"
    ls -lha
    scp -o 'StrictHostKeyChecking no' -i $VAGRANTHOME/.ssh/id_rsa root@10.10.40.11:$VAGRANTHOME/*.pem $VAGRANTHOME
    ls -lha
  fi

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

get_etcd() {
  echo "################## Etcd"
  sudo mkdir -p /etc/etcd /var/lib/etcd
  sudo mv $VAGRANTHOME/ca.pem $VAGRANTHOME/kubernetes.pem $VAGRANTHOME/kubernetes-key.pem /etc/etcd
  wget --quiet https://github.com/coreos/etcd/releases/download/v3.3.9/etcd-v3.3.9-linux-amd64.tar.gz 2>/dev/null
  sleep 1
  tar xvzf etcd-v3.3.9-linux-amd64.tar.gz
  sudo mv etcd-v3.3.9-linux-amd64/etcd* /usr/local/bin/
  sudo sed "s/xx.xx.xx.xx/$MASTERIP/g" $VAGRANTHOME/files/etcd.service > /etc/systemd/system/etcd.service
  sudo systemctl daemon-reload
  sudo systemctl enable etcd
  sudo systemctl start etcd
  sleep 10
  sudo systemctl status etcd --no-pager
}

init_master() {
  echo "################## Initializing Master"
  if [ $THISMASTER -eq 1 ] ; then
    echo "Doing Master1"
  elif [ $THISMASTER -eq 2 ] || [ $THISMASTER -eq 3 ] ; then
    echo "Doing Master"$THISMASTER
  fi
  sudo sed -i "s/ww.ww.ww.ww/$MASTERIP/g" $VAGRANTHOME/files/kubeadm_config.yaml 
  sudo sed -i "s/xx.xx.xx.xx/$MASTERIP/g" $VAGRANTHOME/files/kubeadm_config.yaml 
  # NEEDED ON FUTURE VERSION 1.12
  #sudo systemctl stop etcd
  #sudo rm -rf /var/lib/etcd/member
  sudo kubeadm init --config=$VAGRANTHOME/files/kubeadm_config.yaml
  #sudo scp -r /etc/kubernetes/pki sguyennet@10.10.40.91:~
  su -l vagrant -c 'mkdir -p $HOME/.kube'
  su -l vagrant -c 'sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config'
  su -l vagrant -c 'sudo chown $(id -u):$(id -g) $HOME/.kube/config'
  echo "downloading Calico"
  wget --quiet https://docs.projectcalico.org/v${CALICOV}/getting-started/kubernetes/installation/hosted/rbac-kdd.yaml
  wget --quiet https://docs.projectcalico.org/v${CALICOV}/getting-started/kubernetes/installation/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml
  su -l vagrant -c 'sudo chown $(id -u):$(id -g) $HOME/rbac-kdd.yaml'
  su -l vagrant -c 'sudo chown $(id -u):$(id -g) $HOME/calico.yaml'
  sed -i 's#192.168.0.0/16#10.30.0.0/24#g' $VAGRANTHOME/calico.yaml
  echo "applying Calico"
  su -l vagrant -c 'kubectl apply -f $HOME/rbac-kdd.yaml'
  su -l vagrant -c 'kubectl apply -f $HOME/calico.yaml'
  rm $VAGRANTHOME/rbac-kdd.yaml
  rm $VAGRANTHOME/calico.yaml
}

get_ssh
#update
ssl
#get_kubectl
#get_haproxy
tls
#get_docker
#get_kubethings
#get_etcd
#init_master
