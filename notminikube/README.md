# Local k8s cluster without minikube

## Before you start
cd files
ssh-keygen -t rsa -b 4096 -C "your_email@example.com" -f notminikube
cd ..
vagrant up
vagrant ssh master1
kubectl get no
## TODO:
Mirror the cluster one gets from kops (k8s version?)
Add different addons at a given version (calico 3.2?)
