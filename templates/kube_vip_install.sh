#!/bin/bash

export EIP='${eip}'
CLUSTER_NAME='${cluster_name}'
COUNT='${count}'


function wait_for_path() {
    if [[ $2 == 'dir' ]]; then
        while [ ! -d $1 ]; do
	    echo "$1 not found... Sleeping 10sec"
	    sleep 10
	done
    else
        while [ ! -f $1 ]; do
            echo "$1 not found... Sleeping 10sec"
            sleep 10
        done
    fi
    echo "$1 FOUND!"
}

function gen_kube_vip () {
    # Generate Kube-VIP manifest
    mkdir -p /root/equinix-metal/
    sudo docker run --network host --rm plndr/kube-vip:0.2.3 manifest pod --interface lo \
        --vip $EIP --bgp --controlplane \
        --peerAS $(curl https://metadata.platformequinix.com/metadata | jq '.bgp_neighbors[0].peer_as') \
        --peerAddress $(curl https://metadata.platformequinix.com/metadata | jq -r '.bgp_neighbors[0].peer_ips[0]') \
        --localAS $(curl https://metadata.platformequinix.com/metadata | jq '.bgp_neighbors[0].customer_as') \
        --bgpRouterID $(curl https://metadata.platformequinix.com/metadata | jq -r '.bgp_neighbors[0].customer_ip') \
        | sudo tee /root/equinix-metal/vip.yaml
   # Add port to manifest
   sed -i "s|value: $EIP|value: $EIP\n    - name: port\n      value: \"6444\"|g" /root/equinix-metal/vip.yaml
}
wait_for_path "/etc/kubernetes/admin.conf"
wait_for_path "/etc/kubernetes/manifests" "dir"
if [[ "$COUNT" == "0" ]]; then
    wait_for_path "/root/baremetal/bmctl-workspace/$CLUSTER_NAME/$CLUSTER_NAME-kubeconfig"
else
    while [ ! docker ps ]; do
        echo "Docker not installed yet... Sleeping 10Sec!"
	sleep 10
    done
    echo "Docker installed!"
fi
gen_kube_vip
wait_for_path "/root/equinix-metal/vip.yaml"

# Copy kube-vip manifest to the manifests folder
cp /root/equinix-metal/vip.yaml /etc/kubernetes/manifests/


