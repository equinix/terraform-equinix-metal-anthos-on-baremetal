#!/bin/bash

GREEN='\033[0;32m' # Color green
YELLOW='\033[0;33m' # Color yellow
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

wait_for_path "/var/lib/kubelet/kubeadm-flags.env"

sed -i '/KUBELET_KUBEADM_ARGS/ s/"$/ --cloud-provider=external"/' /var/lib/kubelet/kubeadm-flags.env
sudo systemctl restart kubelet

