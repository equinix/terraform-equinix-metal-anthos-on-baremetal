#!/bin/bash

export EIP='${eip}'
KUBE_VIP_VER='${kube_vip_ver}'
CLUSTER_NAME='${cluster_name}'
COUNT='${count}'
METAL_API_KEY='${auth_token}'
METAL_PROJECT_ID='${project_id}'
GREEN='\033[0;32m' # Color green
YELLOW='\033[0;33m' # Color green
NC='\033[0m' # No Color

function wait_for_path() {
    if [[ $2 == 'dir' ]]; then
        while [ ! -d $1 ]; do
	    printf "$${YELLOW}Waiting for '$1' to be created...$${NC}\n"
	    sleep 10
	done
    else
        while [ ! -f $1 ]; do
	    printf "$${YELLOW}Waiting for '$1' to be created...$${NC}\n"
            sleep 10
        done
    fi
    printf "$${GREEN}$1 FOUND!$${NC}\n"
}

function gen_kube_vip () {
    sudo docker run --network host --rm ghcr.io/kube-vip/kube-vip:v$KUBE_VIP_VER manifest pod \
	--interface lo \
	--vip $EIP \
	--port 6444 \
	--controlplane \
	--bgp \
	--metal \
	--metalKey $METAL_API_KEY \
        --metalProjectID $METAL_PROJECT_ID \
        | sudo tee /root/bootstrap/vip.yaml
}

function wait_for_docker () {

    while ! docker ps &> /dev/null; do
        printf "$${YELLOW}Docker not installed yet... Sleeping 10Sec!$${NC}\n"
        sleep 10
    done
    printf "$${GREEN}Docker installed!$${NC}\n"
}

wait_for_docker
wait_for_path "/etc/kubernetes/manifests" "dir"
wait_for_path "/var/lib/kubelet/kubeadm-flags.env"
if [[ "$COUNT" == "0" ]]; then
    wait_for_path "/etc/kubernetes/admin.conf"
    wait_for_path "/root/baremetal/bmctl-workspace/$CLUSTER_NAME/$CLUSTER_NAME-kubeconfig"
    mkdir -p /root/.kube/
    cp /root/baremetal/bmctl-workspace/$CLUSTER_NAME/$CLUSTER_NAME-kubeconfig /root/.kube/config
    chmod 0600 /root/.kube/config
    gen_kube_vip
elif [[ "$COUNT" == "1" ]]; then
    wait_for_path "/etc/kubernetes/admin.conf"
    printf "$${YELLOW}Wait a full minute before adding Kube-VIP or the cluster join will not complete...$${NC}\n"
    sleep 60
    gen_kube_vip
fi
wait_for_path "/root/bootstrap/vip.yaml"
# Copy kube-vip manifest to the manifests folder
cp /root/bootstrap/vip.yaml /etc/kubernetes/manifests/

if [[ "$COUNT" == "0" ]]; then
    printf "$${GREEN}BGP peering initiated! Cluster should be completed in about 5 minutes.$${NC}\n"
fi

