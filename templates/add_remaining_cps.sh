#!/bin/bash

CLUSTER_NAME='${cluster_name}'
CP_IP_2='${cp_ip_2}'
CP_ID_2='${cp_id_2}'
CP_IP_3='${cp_ip_3}'
CP_ID_3='${cp_id_3}'

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
                    "address": "'$CP_IP_2'", 
                    "providerID": "equinixmetal://'$CP_ID_2'"
                }
            },
            {
                "op": "add",
                "path": "/spec/controlPlane/nodePoolSpec/nodes/2",
                "value": {
                    "address": "'$CP_IP_3'",
                    "providerID": "equinixmetal://'$CP_ID_3'"
                }
            }
        ]'
