#!/bin/bash


if ! command -v gcloud &> /dev/null
then
    echo "The Google Cloud SDK is not installed."
    echo "Pleaase visit https://cloud.google.com/sdk/docs/install for instructions on how to install."
    exit 1
fi

#start the interactive portion to capture user details
echo "This script will help you perform the steps outlined at
https://cloud.google.com/gke-on-prem/docs/how-to/service-accounts"

#log in to gcloud
gcloud init

#capture the project the user selected during log in
PROJECT=$(gcloud config list --format 'value(core.project)')

#create the folder for the keys and set the variable
FOLDER=$(dirname "$0")/keys
mkdir -p -m 700 "$FOLDER"
echo ""
echo "The service account key files will live in $FOLDER/"

GCR='baremetal-gke-gcr'
CONNECT='baremetal-gke-connect'
REGISTER='baremetal-gke-register'
CLOUDOPS='baremetal-gke-cloud-operations'
BMCTL='baremetal-gke-bmctl'

#create the needed service accounts
gcloud iam service-accounts create $GCR --project $PROJECT
gcloud iam service-accounts create $CONNECT --project $PROJECT
gcloud iam service-accounts create $REGISTER --project $PROJECT
gcloud iam service-accounts create $CLOUDOPS --project $PROJECT
gcloud iam service-accounts create $BMCTL --project $PROJECT

#create the needed keys
gcloud iam service-accounts keys create "$FOLDER"/gcr.json --iam-account $GCR@$PROJECT.iam.gserviceaccount.com
gcloud iam service-accounts keys create "$FOLDER"/register.json --iam-account $REGISTER@$PROJECT.iam.gserviceaccount.com
gcloud iam service-accounts keys create "$FOLDER"/connect.json --iam-account $CONNECT@$PROJECT.iam.gserviceaccount.com
gcloud iam service-accounts keys create "$FOLDER"/cloud-ops.json --iam-account $CLOUDOPS@$PROJECT.iam.gserviceaccount.com
gcloud iam service-accounts keys create "$FOLDER"/bmctl.json --iam-account $BMCTL@$PROJECT.iam.gserviceaccount.com

#assign the needed IAM roles
gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$CONNECT@$PROJECT.iam.gserviceaccount.com" --role='roles/gkehub.connect'
gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$REGISTER@$PROJECT.iam.gserviceaccount.com" --role='roles/gkehub.admin'
gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$CLOUDOPS@$PROJECT.iam.gserviceaccount.com" --role='roles/logging.logWriter'
gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$CLOUDOPS@$PROJECT.iam.gserviceaccount.com" --role='roles/monitoring.metricWriter'
gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$CLOUDOPS@$PROJECT.iam.gserviceaccount.com" --role='roles/stackdriver.resourceMetadata.writer'
gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$CLOUDOPS@$PROJECT.iam.gserviceaccount.com" --role='roles/monitoring.dashboardEditor'
gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$BMCTL@$PROJECT.iam.gserviceaccount.com" --role='roles/compute.viewer'
