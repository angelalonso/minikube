# Local k8s cluster without minikube

## Before you start
-- THIS IS OBVIOUSLY NOT A PRODUCTION-READY CLUSTER -- 

-- I NEVER HAD SECURITY ON MY MIND WHILE PUTTING THIS TOGETHER --

-- USE THIS AT YOUR OWN RISK --

## Bring up the cluster
`cd files`  
`ssh-keygen -t rsa -b 4096 -C "your_email@example.com" -f notminikube`  
`mv notminikube notminikube.pem`  
`cd ..`  
`vagrant up`  

-- This will take ~20 minutes to finish, then all masters will be ready in about 2 minutes
## Check your cluster
I am not going to tell you how to manage your cluster from the host machine (scp, aliases...). Instead, I'll assmue you do everything from master1 like:
`vagrant ssh master1  `
`kubectl get no  `
`kubectl get cs  `
`kubectl cluster-info`
## Manually (sorry!) correct podCIDR for the new masters:
`kubectl edit no master2  `
-- Modify and add the following:
`spec:`  
`  externalID: master2  `
`  podCIDR: 10.30.0.0/24  `
`  taints:  `
`    - effect: NoSchedule  `
`      key: node-role.kubernetes.io/master  `
-- repeat for master3
## 
## TODO:
Automate Masters joining properly (no kubectl edit no needed)
Mirror the cluster one gets from kops (k8s version?)
Add different addons at a given version (calico 3.2?)
