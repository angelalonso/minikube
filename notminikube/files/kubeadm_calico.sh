#!/usr/bin/env bash

# Script to do kubeadm init
# meant to be called from the last master to run on the first one

VAGRANTHOME="/home/vagrant"

export DEBIAN_FRONTEND=noninteractive
CLUSTERCIDR="10.30.0.0/24"
HAPROXYIP="10.0.2.15"
THISMASTER=$(hostname | sed 's/master//g')
MASTERIP=$(echo "10.10.40.1"$THISMASTER)

K8SV="1.10.6"
CALICOV="3.0"

echo "Doing Master1"
sudo sed -i "s/ww.ww.ww.ww/$HAPROXYIP/g" $VAGRANTHOME/files/kubeadm_config.yaml
sudo sed -i "s/xx.xx.xx.xx/$MASTERIP/g" $VAGRANTHOME/files/kubeadm_config.yaml
# NEEDED ON FUTURE VERSION 1.12
#sudo systemctl stop etcd
#sudo rm -rf /var/lib/etcd/member
sudo kubeadm reset
sudo kubeadm init --config=$VAGRANTHOME/files/kubeadm_config.yaml --ignore-preflight-errors=ExternalEtcdVersion
su -l vagrant -c 'mkdir -p $HOME/.kube'
su -l vagrant -c 'sudo rm /admin.conf $HOME/.kube/config'
su -l vagrant -c 'sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config'
su -l vagrant -c 'sudo chown $(id -u):$(id -g) $HOME/.kube/config'
echo "downloading Calico"
wget -O /home/vagrant/rbac-kdd.yaml --quiet https://docs.projectcalico.org/v${CALICOV}/getting-started/kubernetes/installation/hosted/rbac-kdd.yaml
wget -O /home/vagrant/calico.yaml --quiet https://docs.projectcalico.org/v${CALICOV}/getting-started/kubernetes/installation/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml
su -l vagrant -c 'sudo chown $(id -u):$(id -g) $HOME/rbac-kdd.yaml'
su -l vagrant -c 'sudo chown $(id -u):$(id -g) $HOME/calico.yaml'
sed -i 's#192.168.0.0/16#10.30.0.0/24#g' $VAGRANTHOME/calico.yaml
echo "applying Calico"
su -l vagrant -c 'kubectl apply -f $HOME/rbac-kdd.yaml'
su -l vagrant -c 'kubectl apply -f $HOME/calico.yaml'
rm $VAGRANTHOME/rbac-kdd.yaml
rm $VAGRANTHOME/calico.yaml

