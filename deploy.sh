#!/usr/bin/env bash

set -eo pipefail

DIR=$(dirname $(readlink -f $0))
HELMDIR="${DIR}/helm"
HELMS=(postgres redis result-app voting-app worker)

create() {
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


destroy() {
  for helm in ${HELMS[@]}
  do
    echo "removing $helm"
    helm delete --purge $helm
  done
  helm delete --purge traefik
}


help(){
  echo "ERROR: Wrong or unrecognized parameter received: $1"
  echo "USAGE:"
  echo "$0 [create|destroy]"
}


main(){
case "$1" in
  destroy)
    destroy;;
  create)
    create;;
  *)
    help "$1";;
esac
}

main "$1"
