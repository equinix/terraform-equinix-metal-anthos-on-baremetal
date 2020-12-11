#!/bin/bash

export EIP='${eip}'
KUBE_VIP_VER='${kube_vip_ver}'
CLUSTER_NAME='${cluster_name}'
COUNT='${count}'
PACKET_API_KEY='${auth_token}'
PACKET_PROJECT_ID='${project_id}'


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

function gen_kube_vip_old () {
    # Generate Kube-VIP manifest
    if [[ "$1" == "cp" ]]; then
        flags="--vip $EIP --controlplane "
    else
        flags="--inCluster --services "
    fi
    sudo docker run --network host --rm plndr/kube-vip:$KUBE_VIP_VER manifest pod \
	--interface lo \
	$flags \
	--bgp \
	--port 6444 \
        --peerAS $(curl https://metadata.platformequinix.com/metadata | jq '.bgp_neighbors[0].peer_as') \
        --peerAddress $(curl https://metadata.platformequinix.com/metadata | jq -r '.bgp_neighbors[0].peer_ips[0]') \
        --localAS $(curl https://metadata.platformequinix.com/metadata | jq '.bgp_neighbors[0].customer_as') \
        --bgpRouterID $(curl https://metadata.platformequinix.com/metadata | jq -r '.bgp_neighbors[0].customer_ip') \
        | sudo tee /root/bootstrap/vip.yaml
}

function gen_kube_vip () {
    sudo docker run --network host --rm plndr/kube-vip:$KUBE_VIP_VER manifest pod \
	--interface lo \
	--vip $EIP \
	--port 6444 \
        --controlplane \
	--bgp \
	--packet \
	--packetKey $PACKET_API_KEY \
	--packetProject "__REPLACE_ME__" \
        | sudo tee /root/bootstrap/vip.yaml
        PROJECT_NAME=$(curl -s https://api.equinix.com/metal/v1/projects/$PACKET_PROJECT_ID -H 'Accept: application/json' -H "X-Auth-Token: $PACKET_API_KEY" | jq -r '.name')
	sed -i "s|__REPLACE_ME__|$PROJECT_NAME|g" /root/bootstrap/vip.yaml
}

function wait_for_docker () {

    while [ ! docker ps ]; do
        echo "Docker not installed yet... Sleeping 10Sec!"
        sleep 10
    done
    echo "Docker installed!"
}

wait_for_docker
wait_for_path "/etc/kubernetes/manifests" "dir"
wait_for_path "/var/lib/kubelet/kubeadm-flags.env"
if [[ "$COUNT" == "0" ]]; then
    wait_for_path "/etc/kubernetes/admin.conf"
    wait_for_path "/root/baremetal/bmctl-workspace/$CLUSTER_NAME/$CLUSTER_NAME-kubeconfig"
    gen_kube_vip "cp"
elif [[ "$COUNT" == "1" ]]; then
    wait_for_path "/etc/kubernetes/admin.conf"
    echo "Wait a full minute before adding Kube-VIP or the cluster join will not complete..."
    sleep 60
    gen_kube_vip "cp"
else
    gen_kube_vip "worker"
fi
wait_for_path "/root/bootstrap/vip.yaml"
# Copy kube-vip manifest to the manifests folder
cp /root/bootstrap/vip.yaml /etc/kubernetes/manifests/

sed -i '/KUBELET_KUBEADM_ARGS/ s/"$/ --cloud-provider=external"/' /var/lib/kubelet/kubeadm-flags.env
sudo systemctl restart kubelet
