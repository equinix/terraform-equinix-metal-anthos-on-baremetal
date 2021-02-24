#!/bin/bash
CLUSTER_NAME='${cluster_name}'
OS='${operating_system}'
CP_VIP='${cp_vip}'
INGRESS_VIP='${ingress_vip}'
ANTHOS_VER='${anthos_ver}'
IFS=' ' read -r -a CP_IPS <<< '${cp_ips}'
IFS=' ' read -r -a WORKER_IPS <<< '${worker_ips}'


function ubuntu_pre_reqs {
    # Install Docker
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get update -qy
    sudo apt-get install apt-transport-https ca-certificates curl software-properties-common gnupg -qy
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable" -y
    sudo apt-get update -qy
    DOCKER_VERSION=`sudo apt-cache madison docker-ce | grep '19.03.13' | awk '{print $3}'`
    sudo apt-get install docker-ce=$DOCKER_VERSION -qy
    sudo usermod -aG docker $USER

    # Install Google Cloud SDK
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
    sudo apt-get update -qy 
    sudo apt-get install google-cloud-sdk -qy
}


function rhel_pre_reqs {
    # Disable Firewalld
    sudo systemctl disable firewalld
    sudo systemctl stop firewalld
    # Disable SELinux
    sudo setenforce 0
    sudo curl -Lo  /etc/yum.repos.d/docker-ce.repo https://download.docker.com/linux/centos/docker-ce.repo

    sudo tee -a /etc/yum.repos.d/google-cloud-sdk.repo << EOM
[google-cloud-sdk]
name=Google Cloud SDK
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOM
    sudo yum -q makecache -y --disablerepo='*' --enablerepo=google-cloud-sdk
    DOCKER_VERSION=`sudo dnf --showduplicates list docker-ce | grep '19.03.13' | awk '{print $2}'`
    sudo dnf install docker-ce-$DOCKER_VERSION iptables google-cloud-sdk python3 -y
    sudo systemctl enable --now docker
}


function unknown_os {
    echo "I don't know who I am" > /root/who_am_i.txt
}

if [ "$${OS:0:6}" = "centos" ] || [ "$${OS:0:4}" = "rhel" ]; then
    rhel_pre_reqs
elif [ "$${OS:0:6}" = "ubuntu" ]; then
    ubuntu_pre_reqs
else
    unknown_os
fi

# Install kubectl
curl -LO "https://storage.googleapis.com/kubernetes-release/release/v1.18.6/bin/linux/amd64/kubectl"
chmod a+x kubectl
sudo mv kubectl /usr/local/bin/

# Assing CP VIP to first master node's lo interface
export EIP=$CP_VIP
ip add add $EIP/32 dev lo

# Download bmctl
cd /root/baremetal
gcloud auth activate-service-account --key-file=keys/gcr.json
gsutil cp gs://anthos-baremetal-release/bmctl/$ANTHOS_VER/linux-amd64/bmctl .
chmod a+x bmctl

./bmctl create config -c $CLUSTER_NAME
bmctl_workspace='/root/baremetal/bmctl-workspace'
cluster_config="$bmctl_workspace/$CLUSTER_NAME/$CLUSTER_NAME.yaml"
GCP_PROJECT_ID=`grep 'project_id' /root/baremetal/keys/register.json | awk -F'"' '{print $4}'`
cp_string="      - address: $${CP_IPS[0]}"$'\\n'
for i in "$${WORKER_IPS[@]}"; do
   worker_string="$worker_string  - address: $i"$'\\n'
done

# Replace variables in cluster config
sed -i "/Node pool configuration is only valid for 'bundled' LB mode./,+4 d" $cluster_config
sed -i "s|<path to GCR service account key>|/root/baremetal/keys/gcr.json|g" $cluster_config
sed -i "s|<path to SSH private key, used for node access>|/root/.ssh/id_rsa|g" $cluster_config
sed -i "s|<path to Connect agent service account key>|/root/baremetal/keys/connect.json|g" $cluster_config
sed -i "s|<path to Hub registration service account key>|/root/baremetal/keys/register.json|g" $cluster_config
sed -i "s|<path to Cloud Operations service account key>|/root/baremetal/keys/cloud-ops.json|g" $cluster_config
sed -i "s|type: admin|type: hybrid|g" $cluster_config
sed -i "s|<GCP project ID>|$GCP_PROJECT_ID|g" $cluster_config
sed -i "s|  - address: <Machine 3 IP>||g" $cluster_config
sed -i "s|mode: bundled|mode: manual|g" $cluster_config
sed -i "s|controlPlaneLBPort: 443|controlPlaneLBPort: 6444|g" $cluster_config
sed -i "s|controlPlaneVIP: 10.0.0.8|controlPlaneVIP: $CP_VIP|g" $cluster_config
sed -i "s|# ingressVIP: 10.0.0.2|ingressVIP: $INGRESS_VIP|g" $cluster_config
sed -i "s|      - address: <Machine 1 IP>|$cp_string|g" $cluster_config
sed -i "s|  - address: <Machine 2 IP>|$worker_string|g" $cluster_config
sed -i "s|- 10.96.0.0/12|- 172.31.0.0/16|g" $cluster_config
sed -i "s|- 192.168.0.0/16|- 172.30.0.0/16|g" $cluster_config
