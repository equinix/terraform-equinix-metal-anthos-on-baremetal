#!/bin/bash


if ! command -v gcloud &> /dev/null
then
    echo "The Google Cloud SDK is not installed."
    echo "Pleaase visit https://cloud.google.com/sdk/docs/install for instructions on how to install."
    exit 1
fi

#start the interactive portion to capture user details
echo "This script will help you perform the steps outlined at
https://cloud.google.com/gke-on-prem/docs/how-to/service-accounts

Enter the name of the email of your Google Container Registry (GCR) service account"
read -p "(example: baremetal-gcr@my-anthos-project.iam.gserviceaccount.com):" GCR_SA_EMAIL

#log in to gcloud
gcloud init

#capture the project the user selected during log in
PROJECT=$(gcloud config list --format 'value(core.project)')

#create the folder for the keys and set the variable
FOLDER=$(dirname "$0")/keys
mkdir -p -m 700 "$FOLDER"
echo ""
echo "The service account key files will live in $FOLDER/"

CONNECT='baremetal-gke-connect'
REGISTER='baremetal-gke-register'
CLOUDOPS='baremetal-gke-cloud-operations'
SUPERADMIN='baremetal-gke-super-admin'

#create the needed service accounts
gcloud iam service-accounts create $CONNECT --project $PROJECT
gcloud iam service-accounts create $REGISTER --project $PROJECT
gcloud iam service-accounts create $CLOUDOPS --project $PROJECT
gcloud iam service-accounts create $SUPERADMIN --project $PROJECT

#create the needed keys
gcloud iam service-accounts keys create "$FOLDER"/gcr.json --iam-account  $GCR_SA_EMAIL
gcloud iam service-accounts keys create "$FOLDER"/register.json --iam-account $REGISTER@$PROJECT.iam.gserviceaccount.com
gcloud iam service-accounts keys create "$FOLDER"/connect.json --iam-account $CONNECT@$PROJECT.iam.gserviceaccount.com
gcloud iam service-accounts keys create "$FOLDER"/cluster-ops.json --iam-account $CLOUDOPS@$PROJECT.iam.gserviceaccount.com
gcloud iam service-accounts keys create "$FOLDER"/super-admin.json --iam-account $SUPERADMIN@$PROJECT.iam.gserviceaccount.com


#assign the needed IAM roles
gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$CONNECT@$PROJECT.iam.gserviceaccount.com" --role='roles/gkehub.connect'
gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$REGISTER@$PROJECT.iam.gserviceaccount.com" --role='roles/gkehub.admin'
gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$CLOUDOPS@$PROJECT.iam.gserviceaccount.com" --role='roles/logging.logWriter'
gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$CLOUDOPS@$PROJECT.iam.gserviceaccount.com" --role='roles/monitoring.metricWriter'
gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$CLOUDOPS@$PROJECT.iam.gserviceaccount.com" --role='roles/stackdriver.resourceMetadata.writer'
gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$CLOUDOPS@$PROJECT.iam.gserviceaccount.com" --role='roles/monitoring.dashboardEditor'
gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$SUPERADMIN@$PROJECT.iam.gserviceaccount.com" --role='roles/iam.serviceAccountAdmin'
gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$SUPERADMIN@$PROJECT.iam.gserviceaccount.com" --role='roles/iam.serviceAccountKeyAdmin'
gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$SUPERADMIN@$PROJECT.iam.gserviceaccount.com" --role='roles/resourcemanager.projectIamAdmin'
gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$SUPERADMIN@$PROJECT.iam.gserviceaccount.com" --role='roles/editor'


#enable the required APIs for the project
gcloud services enable \
    anthos.googleapis.com \
    anthosgke.googleapis.com \
    cloudresourcemanager.googleapis.com \
    container.googleapis.com \
    iam.googleapis.com \
    gkeconnect.googleapis.com \
    gkehub.googleapis.com \
    serviceusage.googleapis.com \
    stackdriver.googleapis.com \
    monitoring.googleapis.com \
    logging.googleapis.com --project $PROJECT
