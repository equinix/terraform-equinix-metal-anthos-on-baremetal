#!/bin/bash

CLUSTER_NAME='${cluster_name}'
CP_2='${cp_2}'
CP_3='${cp_3}'

mkdir -p /root/.kube/

cp /root/baremetal/bmctl-workspace/$CLUSTER_NAME/$CLUSTER_NAME-kubeconfig /root/.kube/config
# Wait a minute for things to settle
#echo "Waiting for 60 seconds to let the cluster settle"
#sleep 60
kubectl \
    --kubeconfig /root/baremetal/bmctl-workspace/$CLUSTER_NAME/$CLUSTER_NAME-kubeconfig \
    -n cluster-$CLUSTER_NAME \
    patch cluster $CLUSTER_NAME \
    --type json \
    -p '[
            {
                "op": "add",
                "path": "/spec/controlPlane/nodePoolSpec/nodes/1",
                "value": {
                "address": "'$CP_2'"
                }
            },
            {
                "op": "add",
                "path": "/spec/controlPlane/nodePoolSpec/nodes/2",
                "value": {
                "address": "'$CP_3'"
                }
            }
        ]'
