#!/usr/bin/env bash
set -eo pipefail
# https://twitter.com/JetstackHQ/status/935486815318011904

cat <<EOF > ~/.minikube/addons/audit-policy.yaml
#Log all requests at the metadata level
apiVersion: audit.k8s.io/v1beta1
kind: Policy
rules:
- level: Metadata
EOF

minikube start \
  --extra-config=apiserver.authorization-mode=RBAC \
  #--extra-config=apiserver.Audit.LogOptions.Path=/var/log/apiserver/audit.log \
  --extra-config=apiserver.audit-log-path=/home/docker/audit.log \
  --extra-config=apiserver.audit-log-maxage=30 \
  --extra-config=apiserver.audit-log-maxsize=400 \
  --extra-config=apiserver.audit-log-maxbackup=5

#minikube start \
  #RBAC is default
#  --extra-config=apiserver.Authorization.Mode=RBAC \
  #--extra-config=apiserver.authorization-mode=RBAC \
  #--extra-config=apiserver.audit-log-path=/hostname/$USER/.minikube/logs/audit.log \
  #--extra-config=apiserver.Audit.LogOptions.Path=/hostname/$USER/.minikube/logs/audit.log \
  #--extra-config=apiserver.audit-log-path=/etc/kubernetes/addons/audit-policy.yaml \
#  --extra-config=apiserver.audit-log-path=/var/log/apiserver/audit.log
  #--kubernetes-version v1.11.5

# It somehow needs a restart to have the api up and running
#minikube stop
#minikube start

helm init
