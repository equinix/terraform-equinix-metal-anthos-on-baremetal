#!/bin/bash
CLUSTER_NAME='${cluster_name}'

cd /root/baremetal
export GOOGLE_APPLICATION_CREDENTIALS=/root/baremetal/keys/super-admin.json
GREEN='\033[0;32m' # Color green
NC='\033[0m' # No Color
printf "\n$${GREEN}Creating Anthos Cluster. This will take about 20 minutes...$${NC}\n"
/root/baremetal/bmctl create cluster -c $CLUSTER_NAME --force &> /root/baremetal/cluster_create.log
