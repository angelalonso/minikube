#!/usr/bin/env bash

MASTER_IP="192.168.0.1"
TOKEN="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx::node:yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy"

/usr/bin/nohup /usr/local/bin/k3s agent --server https://${MASTER_IP}:6443 --token ${TOKEN} &

