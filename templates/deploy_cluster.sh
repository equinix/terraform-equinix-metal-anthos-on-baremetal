#!/bin/bash
# Install Docker
sudo apt update -y
sudo apt install apt-transport-https ca-certificates curl software-properties-common gnupg -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable" -y
sudo apt update -y
sudo apt install docker-ce -y
sudo usermod -aG docker $USER

# Install Google Cloud SDK
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
sudo apt-get update -y 
sudo apt-get install google-cloud-sdk -y

# Install kubectl
curl -LO "https://storage.googleapis.com/kubernetes-release/release/v1.18.6/bin/linux/amd64/kubectl"
chmod a+x kubectl
sudo mv kubectl /usr/local/bin/

# Download bmctl
cd /root/baremetal
gcloud auth activate-service-account --key-file=keys/gcr.json
gsutil cp gs://anthos-baremetal-release/bmctl/0.7.0-gke.4/linux/bmctl .
chmod a+x bmctl

# Generate boilerplate cluster config
CLUSTER_NAME="${cluster_name}"
./bmctl create config -c $CLUSTER_NAME

# Replace variables in cluster config
sed -i "s|<path to GCR service account key>|/root/baremetal/keys/gcr.json|g" /root/baremetal/bmctl-workspace/$CLUSTER_NAME/$CLUSTER_NAME.yaml
sed -i "s|<path to SSH private key, used for node access>|/root/.ssh/id_rsa|g" /root/baremetal/bmctl-workspace/$CLUSTER_NAME/$CLUSTER_NAME.yaml
sed -i "s|<path to Connect agent service account key>|/root/baremetal/keys/connect.json|g" /root/baremetal/bmctl-workspace/$CLUSTER_NAME/$CLUSTER_NAME.yaml
sed -i "s|<path to Hub registration service account key>|/root/baremetal/keys/register.json|g" /root/baremetal/bmctl-workspace/$CLUSTER_NAME/$CLUSTER_NAME.yaml
sed -i "s|<path to Cloud Operations service account key>|/root/baremetal/keys/cluster-ops.json|g" /root/baremetal/bmctl-workspace/$CLUSTER_NAME/$CLUSTER_NAME.yaml
GCP_PROJECT_ID=`grep 'project_id' /root/baremetal/keys/register.json | awk -F'"' '{print $4}'`
sed -i "s|type: admin|type: hybrid|g" /root/baremetal/bmctl-workspace/$CLUSTER_NAME/$CLUSTER_NAME.yaml
sed -i "s|<GCP project ID>|$GCP_PROJECT_ID|g" /root/baremetal/bmctl-workspace/$CLUSTER_NAME/$CLUSTER_NAME.yaml
sed -i "s|  - address: <Machine 3 IP>||g" /root/baremetal/bmctl-workspace/$CLUSTER_NAME/$CLUSTER_NAME.yaml
sed -i "s|    # addressPools:|    addressPools:|g" /root/baremetal/bmctl-workspace/$CLUSTER_NAME/$CLUSTER_NAME.yaml
sed -i "s|    # - name: pool1|    - name: pool1|g" /root/baremetal/bmctl-workspace/$CLUSTER_NAME/$CLUSTER_NAME.yaml
sed -i "s|    #   addresses:|      addresses:|g" /root/baremetal/bmctl-workspace/$CLUSTER_NAME/$CLUSTER_NAME.yaml

