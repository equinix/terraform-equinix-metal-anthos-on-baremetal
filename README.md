# Anthos Baremetal on Equinix Metal
This is a very basic terraform template that will deploy ***N*** number of nodes (Defaults to 2) and configure a private vLan and IPs between these nodes using Equinix Metal's ***Mixed/Hybrid*** networking.
## Download this project
To download this project, run the following command:

```bash
git clone https://github.com/c0dyhi11/baremetal-anthos.git
cd baremetal-anthos
```

## Generate your GCP Keys
There is a helper script in the `util` directory named `setup_gcp_project.sh`. You will need. The Google Cloud SDK installed to run this, and you'll most likley need to have the `Project Owner Role`.

Once your keys are generated you should have a folder named `keys` in the `util` directory with the following files:
```
util
|_keys
  |_cluster-ops.json
  |_connect.json
  |_gcr.json
  |_register.json
  |_super-admin.json
```
## Install Terraform 
Terraform is just a single binary.  Visit their [download page](https://www.terraform.io/downloads.html), choose your operating system, make the binary executable, and move it into your path. 
 
Here is an example for **macOS**: 
```bash 
curl -LO https://releases.hashicorp.com/terraform/0.12.29/terraform_0.12.29_darwin_amd64.zip 
unzip terraform_0.12.29_darwin_amd64.zip 
chmod +x terraform 
sudo mv terraform /usr/local/bin/
rm -f terraform_0.12.29_darwin_amd64.zip 
``` 
Here is an example for **Linux**:
```bash
curl -LO https://releases.hashicorp.com/terraform/0.12.29/terraform_0.12.29_linux_amd64.zip
unzip terraform_0.12.29_linux_amd64.zip
chmod +x terraform 
sudo mv terraform /usr/local/bin/
rm -f terraform_0.12.29_linux_amd64.zip
```
## Modify your variables 
You will need to set two variables at a minimum and there are a lot more you may wish to modify in `variables.tf`. This file must be created in your `baremetal-anthos` directory
```bash 
cat <<EOF >terraform.tfvars 
auth_token = "<enter your Project API token here>"
project_id = "<enter your Packet Project ID here>"
EOF
``` 
There are a lot more variables that can be modified in the `variables.tf` file. Those variables are documented below.

## Initialize Terraform 
Terraform uses modules to deploy infrastructure. In order to initialize the modules your simply run: `terraform init`. This should download modules into a hidden directory `.terraform` 

## Deploy terraform template
```bash
terraform apply --auto-approve
```
Once this is complete you should get output similar to this:
```
Apply complete! Resources: 27 added, 0 changed, 0 destroyed.

Outputs:

Bastion_Hostname = packet-gke-cluster-bastion
Bastion_Public_IP = 145.40.65.153
Bastion_Tags = [
  "bastion",
  "anthos",
  "baremetal",
  "172.29.254.1",
]
Control_Plane_Public_IPs = [
  "145.40.65.89",
  "145.40.65.95",
  "145.40.65.123",
]
Control_Plane_Hostnames = [
  "packet-gke-cluster-cp-01",
  "packet-gke-cluster-cp-02",
  "packet-gke-cluster-cp-03",
]
Control_Plane_Tags = [
  [
    "anthos",
    "baremetal",
    "172.29.254.2",
  ],
  [
    "anthos",
    "baremetal",
    "172.29.254.3",
  ],
  [
    "anthos",
    "baremetal",
    "172.29.254.4",
  ],
]
Worker_Node_Hostnames = [
  "packet-gke-cluster-worker-01",
  "packet-gke-cluster-worker-02",
  "packet-gke-cluster-worker-03",
]
Worker_Node_Tags = [
  [
    "anthos",
    "baremetal",
    "172.29.254.5",
  ],
  [
    "anthos",
    "baremetal",
    "172.29.254.6",
  ],
  [
    "anthos",
    "baremetal",
    "172.29.254.7",
  ],
]
Worker_Public_IPs = [
  "145.40.65.103",
  "145.40.65.61",
  "145.40.65.155",
]
```

## Tested Operating Systems

| Name | Api Slug |
| :--: |:-------: |
| CentOS 8 | centos_8 |
| RedHat Enterprise Linux 8 | rhel_8 |
| Ubuntu 18.04 | ubuntu_18_04 |
| Ubutnu 20.04 | ubuntu_20_04 |

## Variables
| Variable Name | Type | Default Value | Description |
| :-----------: |:---: | :------------:|:------------|
| auth_token | string | n/a | Packet API Key |
| project_id | string | n/a | Packet Project ID |
| hostname | string | anthos-baremetal | The hostname for nodes |
| facility | string | sv15 | Packet  Facility  to  deploy  into |
| plan | string | c3.small.x86 | Packet  device  type  to  deploy |
| ha_control_plane | boolean | true | Do you want a highly available control plane? |
| worker_count | number | 3 | Number  of  worker  nodes |
| operating_system | string | ubuntu_20_04 | The  Operating  system  of  the  node |
| billing_cycle | string | hourly | How  the  node  will  be  billed (Not  usually  changed) |
| private_subnet | string | 172.29.254.0/24 | Private  IP  Space  to  use  for  Layer2 |
| cluster_name | string | equinix-metal-gke-cluster | The name of teh GKE cluster |

## Testing script
I had the need to see if my terraform script would work on each operating system. So I wrote ***test_matrix.sh*** to handle this for me. This script is located in the `util` directory. This script has a bunch of operating systems in a list and will execute the terraform scripts into folder for each OS. The output of the terraform script is stored in that dedicated directory in a file called terraform.log.

To run this script simply do the following:
```bash
./test_matrix.sh apply
```
Once you are finished, you can tear it all down as follows:
```bash
./test_matrix.sh destroy
```

## Know issues
You can't create and destory the same `cluster_name` more than once without deleting the cluster from the Google Cloud GKE console. In order to try and remedy this. I'm adding a random 5-digit string to the `cluster_name`
