#!/usr/bin/env bash

set -eo pipefail

DIR=$(dirname $(readlink -f $0))
HELMS=(postgres redis result-app voting-app worker)

create() {
  for helm in ${HELMS[@]}
  do
    echo "adding $helm"
    helm install --name $helm $DIR/helm/$helm
  done
}


destroy() {
  for helm in ${HELMS[@]}
  do
    echo "removing $helm"
    helm delete --purge $helm
  done
}

create
#destroy
