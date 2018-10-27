# Local k8s cluster without minikube

## Before you start
-- THIS IS OBVIOUSLY NOT A PRODUCTION-READY CLUSTER -- 
-- I NEVER HAD SECURITY ON MY MIND WHILE PUTTING THIS TOGETHER --
-- USE THIS AT YOUR OWN RISK --
cd files
ssh-keygen -t rsa -b 4096 -C "your_email@example.com" -f notminikube
mv notminikube notminikube.pem
cd ..
vagrant up
-- This will take ~20 minutes to finish, then all masters will be ready in about 2 minutes
vagrant ssh master1
kubectl get no
## TODO:
Mirror the cluster one gets from kops (k8s version?)
Add different addons at a given version (calico 3.2?)
