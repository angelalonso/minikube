# Local k8s cluster without minikube

## Before you start
cd files
ssh-keygen -t rsa -b 4096 -C "your_email@example.com" -f notminikube
, and then from the main folder...
vagrant up
vagrant ssh master1
kubectl get no
## TODO:
Bring several masters up
Make them work together
Mirror the cluster one gets from kops (k8s version?)
Add different addons at a given version (calico 3.2?)
