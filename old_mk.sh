#!/usr/bin/env bash

set -eo pipefail

MEMSIZE=1536
DIR=$(dirname $(readlink -f $0))
HELMDIR="${DIR}/helm"
HELMS=(postgres redis result-app voting-app worker)

create() {
  minikube start \
    --memory=$MEMSIZE \
    --extra-config=apiserver.Authorization.Mode=RBAC
   
  sleep 20
  kubectl create clusterrolebinding add-on-cluster-admin --clusterrole=cluster-admin --serviceaccount=kube-system:default
}


destroy() {
  minikube destroy
}


deploy() {
  helm init
  for nspacepath in $(ls -d ${HELMDIR}/*/)
  do
    nspace=$(basename $nspacepath)
    for chartpath in $(ls -d ${nspacepath}*/)
    do
      chart=$(basename $chartpath)
      echo "adding $chart"
      helm install --name $chart $chartpath --namespace $nspace
    done
  done
}


clean() {
  for nspacepath in $(ls -d ${HELMDIR}/*/)
  do
    nspace=$(basename $nspacepath)
    for chartpath in $(ls -d ${nspacepath}*/)
    do
      chart=$(basename $chartpath)
      echo "removing $chart"
      helm delete --purge $chart
    done
  done
}


help(){
  echo "ERROR: Wrong or unrecognized parameter received: $1"
  echo "USAGE:"
  echo "$0 [create|destroy|deploy|clean]"
}


main(){
case "$1" in
  create)
    create;;
  destroy)
    destroy;;
  deploy)
    deploy;;
  clean)
    clean;;
  *)
    help "$1";;
esac
}

main "$1"

