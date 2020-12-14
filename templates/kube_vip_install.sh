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
	    echo "Waiting for '$1' to be created..."
	    sleep 10
	done
    else
        while [ ! -f $1 ]; do
	    echo "Waiting for '$1' to be created..."
            sleep 10
        done
    fi
    echo "$1 FOUND!"
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
        --packetProjectID $PACKET_PROJECT_ID \
        | sudo tee /root/bootstrap/vip.yaml
    # Hack until manifest doesn't include this path
    sed  -i "/\/etc\/ssl\/certs/,+2 d" /root/bootstrap/vip.yaml
}

function wait_for_docker () {

    while ! docker ps &> /dev/null; do
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
    gen_kube_vip
elif [[ "$COUNT" == "1" ]]; then
    wait_for_path "/etc/kubernetes/admin.conf"
    echo "Wait a full minute before adding Kube-VIP or the cluster join will not complete..."
    sleep 60
    gen_kube_vip
fi
wait_for_path "/root/bootstrap/vip.yaml"
# Copy kube-vip manifest to the manifests folder
cp /root/bootstrap/vip.yaml /etc/kubernetes/manifests/

sed -i '/KUBELET_KUBEADM_ARGS/ s/"$/ --cloud-provider=external"/' /var/lib/kubelet/kubeadm-flags.env
sudo systemctl restart kubelet

