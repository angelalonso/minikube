#!/usr/bin/env bash

set -eo pipefail

minikube start \
  --memory=1536 \
  --extra-config=apiserver.Authorization.Mode=RBAC

sleep 20
kubectl create clusterrolebinding add-on-cluster-admin --clusterrole=cluster-admin --serviceaccount=kube-system:default

