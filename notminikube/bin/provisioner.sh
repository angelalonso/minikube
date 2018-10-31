#!/usr/bin/env bash
#TODO:
# remove authorized_keys from root user
# clean up inconsistency between use of root and sudo everywhere
VAGRANTHOME="/home/vagrant"

export DEBIAN_FRONTEND=noninteractive
CLUSTERCIDR="10.30.0.0/24"
HAPROXYIP="10.0.2.15"
THISMASTER=$(hostname | sed 's/master//g')
MASTERIP=$(echo "10.10.40.1"$THISMASTER)

echo "##############################"
echo $MASTERIP
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
  sudo apt-get update && \
  sudo apt-get -y upgrade && \
  sudo apt-get install -y \
  apt-transport-https \
  curl \
  chrony \
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
  if [ $THISMASTER -eq 1 ] ; then
    echo "################## haproxy "
    sudo apt-get install -y haproxy
    sudo sed -i "s/ww.ww.ww.ww/$MASTERIP/g" $VAGRANTHOME/files/haproxy.cfg
    sudo sed "s/xx.xx.xx.xx/$MASTERIP/g" $VAGRANTHOME/files/haproxy.cfg > /etc/haproxy/haproxy.cfg
    sudo systemctl restart haproxy
  fi
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
      -hostname=10.10.40.11,10.10.40.12,10.10.40.13,10.0.2.15,127.0.0.1,kubernetes.default \
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
  sudo cp $VAGRANTHOME/ca.pem $VAGRANTHOME/kubernetes.pem $VAGRANTHOME/kubernetes-key.pem /etc/etcd
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
  # We need to do this ONLY when all three nodes on ETCD are up and running.
  #  therefore, I only call master1 and master2 when all three masters are done.
  if [ $THISMASTER -eq 3 ] ; then
    echo "## Now that ETCD is running on all three masters, I'll call kubeadm init on master1"
    echo "Doing Master1!"
    ssh -o 'StrictHostKeyChecking no' -i /home/vagrant/.ssh/id_rsa root@10.10.40.11 "$VAGRANTHOME/files/kubeadm_calico.sh"
    CMD=$(ssh -o 'StrictHostKeyChecking no' -i /home/vagrant/.ssh/id_rsa root@10.10.40.11 "kubeadm token create --print-join-command")
    echo "## also will call kubeadm join on the other masters"
    echo "Doing Master2!"
    ssh -o 'StrictHostKeyChecking no' -i /home/vagrant/.ssh/id_rsa root@10.10.40.12 "kubeadm reset"
    ssh -o 'StrictHostKeyChecking no' -i /home/vagrant/.ssh/id_rsa root@10.10.40.12 "$CMD --ignore-preflight-errors=CRI"
    # We need to give the cluster some time to have the new master ready
    echo "waiting 20 secs"
    sleep 20
    ssh -o 'StrictHostKeyChecking no' -i /home/vagrant/.ssh/id_rsa vagrant@10.10.40.11 "kubectl label node master2 node-role.kubernetes.io/master="
    echo "Doing Master3!"
    kubeadm reset
    $CMD --ignore-preflight-errors=CRI
    # We need to give the cluster some time to have the new master ready
    echo "waiting 20 secs"
    sleep 20 
    ssh -o 'StrictHostKeyChecking no' -i /home/vagrant/.ssh/id_rsa vagrant@10.10.40.11 "kubectl label node master3 node-role.kubernetes.io/master="
  fi
}

get_ssh
update
ssl
get_kubectl
get_haproxy
tls
get_docker
get_kubethings
get_etcd
init_master
