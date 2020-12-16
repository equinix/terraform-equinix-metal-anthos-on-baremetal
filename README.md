[![Equinix Metal Website](https://img.shields.io/badge/Website%3A-metal.equinix.com-blue)](http://metal.equinix.com) [![Slack Status](https://slack.equinixmetal.com/badge.svg)](https://slack.equinixmetal.com/) [![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](http://makeapullrequest.com) ![](https://img.shields.io/badge/Stability-Experimental-red.svg)

# Automated Anthos on Baremetal via Terraform for Equinix Metal
These files will allow you to use [Terraform](http://terraform.io) to deploy [Google Cloud's Anthos on Baremetal](https://cloud.google.com/anthos) on [Equinix Metal's Bare Metal Cloud offering](http://metal.equinix.com). 

Terraform will create an Equinix Metal project complete with Linux machines for your Anthos on Baremetal cluster registered to Google Cloud. You can use an existing Equinix Metal Project, check this [section](#use-an-existing-equinix-metal-project) for instructions.

![Environment Diagram](docs/images/Google-Anthos-Baremetal-BGP-Network-Diagram.png)

Users are responsible for providing their Equinix Metal account, and Anthos subscription as described in this readme.

The build (with default settings) typically takes 25-30 minutes.

**The automation in the repo is COMMUNITY SUPPORTED ONLY**, if the installation succeeds, and you run the Anthos Platform Validation this cluster is production grade and supportable by Google for Anthos and Equinix Metal for Infrastructure. If you have any questions please consult with Equinix Metal Support via a support ticket.

## Join us on Slack
We use [Slack](https://slack.com/) as our primary communication tool for collaboration. You can join the Equinix Metal Community Slack group by going to [slack.equinixmetal.com](https://slack.equinixmetal.com/) and submitting your email address. You will receive a message with an invite link. Once you enter the Slack group, join the **#google-anthos** channel! Feel free to introduce yourself there, but know it's not mandatory.

## Latest Updates
### 12-14-2020
This is the initial release of this project. We support Ubuntu 20.04, Ubuntu 18.04, & CentOS 8. Red Hat Enterprise Linux is in the works. 

## Prerequisites
To use these Terraform files, you need to have the following Prerequisites:
* An [Anthos subscription](https://cloud.google.com/anthos/docs/getting-started)
* Google Cloud service-account keys, check this [section](#-service-account-generation)
* A Equinix Metal org-id and [API key](https://metal.equinix.com/developers/api/)

 
## Associated Equinix Metal Costs
The default variables make use of 6 [c3.small.x86](https://metal.equinix.com/product/servers/) servers. These servers are $0.50 per hour list price (resulting in a total solution price of roughly $3.00 per hour). This deployment has been test with as little as 2 [c3.small.x86](https://metal.equinix.com/product/servers/) (1 Control Plane node and 1 Worker node) for a total cost of roughly $1.00.


## Tested Anthos on Baremetal versions
The Terraform has been successfully tested with following versions of Anthos on Baremetal:
* 1.6.0

To simplify setup, this is designed to use manual LoadBalancing with [Kube-VIP](https://kube-vip.io) load balancer. No other load balancer support is planned at this time.

Select the version of Anthos you wish to install by setting the `anthos_version` variable in your terraform.tfvars file. 


## Download/Create your GCP Keys for your service accounts and activate APIs for your project
The Anthos on Baremetal install requires several service accounts and keys to be created. See the [Google documentation](https://cloud.google.com/anthos/gke/docs/bare-metal/1.6/installing/install-prereq#service_accounts_prerequisites) for more details. You can create these keys manually, or use a provided helper script to make the keys for you (Recommended).

The Terraform files expect the keys to use the following naming convention, matching that of the Google documentation:
```
util
|_keys
  |_cluster-ops.json
  |_connect.json
  |_gcr.json
  |_register.json
  |_super-admin.json
```

If doing so manually, you must create each of these keys and place it in a folder named `keys` within the `util` folder. 
The service accounts also need to have IAM roles assigned to each of them. To do this manually, you'll need to follow the [instructions from Google](https://cloud.google.com/anthos/gke/docs/bare-metal/1.6/installing/install-prereq#service_accounts_prerequisites)


Anthos on Baremetal also requires [several APIs](https://cloud.google.com/gke-on-prem/docs/how-to/gcp-project#enable_apis) to be activated on your target project.

Much easier (and recommended) is to use the helper script located in the `util` directory called `setup_gcp_project.sh` to create these keys, assign the IAM roles, and activate the APIs. The script will allow you to log into GCP with your user account and the GCP project for your Anthos cluster.

You can run this script as follows: 

`util/setup_gcp_project.sh`

Prompts will guide you through the setup. 
 
## Install Terraform

Terraform is just a single binary. Visit their [download page](https://www.terraform.io/downloads.html), choose your operating system, make the binary executable, and move it into your path.

Here is an example for **macOS**:

```bash
curl -LO https://releases.hashicorp.com/terraform/0.14.2/terraform_0.14.2_darwin_amd64.zip
unzip terraform_0.14.2_darwin_amd64.zip
chmod +x terraform
sudo mv terraform /usr/local/bin/
rm -f terraform_0.14.2_darwin_amd64.zip
```

Here is an example for **Linux**:

```bash
curl -LO https://releases.hashicorp.com/terraform/0.14.2/terraform_0.14.2_linux_amd64.zip
unzip terraform_0.14.2_linux_amd64.zip
chmod +x terraform
sudo mv terraform /usr/local/bin/
rm -f terraform_0.14.2_linux_amd64.zip
```

 
## Download this project
To download this project, run the following command:

```bash
git clone https://github.com/equinix/terraform-metal-anthos-on-baremetal.git
cd terraform-metal-anthos-on-baremetal
```

## Initialize Terraform 
Terraform uses modules to deploy infrastructure. In order to initialize the modules your simply run:
```
terraform init
```
This should download six modules into a hidden directory `.terraform` 
 
## Modify your variables 
There are many variables which can be set to customize your install within `variables.tf`. The default variables to bring up a 6 node Anthos cluster with an HA Control Plane and three worker nodes using Equinix Metal's [c3.small.x86](https://metal.equinix.com/product/servers/). Change each default variable at your own risk. 

There are some variables you must set with a terraform.tfvars files. You need to set `auth_token` & `organization_id` to connect to Equinix Metal and the `project_name` which will be created in Equinix Metal. And it's a good idea to set `cluster_name` to identify your cluster in the GCP portal.

The Anthos variables include `anthos_version` and `anthos_user_cluster_name`.
 
Here is a quick command plus sample values to start file for you (make sure you adjust the variables to match your environment): 
```bash 
cat <<EOF >terraform.tfvars 
auth_token = "cefa5c94-e8ee-4577-bff8-1d1edca93ed8" 
organization_id = "42259e34-d300-48b3-b3e1-d5165cd14169" 
project_name = "anthos-metal-project-1"
cluster_name = "my-first-anthos-cluster"
EOF
``` 
### Available Variables
|    Variable Name       |  Type   |        Default Value        | Description                                             |
| :--------------------: | :-----: | :-------------------------: | :------------------------------------------------------ |
|      auth_token        | string  |             n/a             | Equinix Metal API Key                                   |
|      project_id        | string  |             n/a             | Equinix Metal Project ID                                |
|   organization_id      | string  |             n/a.            | Equinix Metal Organization ID                           |
|       hostname         | string  |      anthos-baremetal       | The hostname for nodes                                  |
|       facility         | string  |            sv15             | Equinix Metal Facility to deploy into                   |
|       cp_plan          | string  |        c3.small.x86         | Equinix Metal device type to deploy control plane nodes |
|     worker_plan        | string  |        c3.small.x86         | Equinix Metal device type to deploy for worker nodes    |
|   ha_control_plane     | boolean |            true             | Do you want a highly available control plane?           |
|     worker_count       | number  |              3              | Number of baremetal worker nodes                        |
|   operating_system     | string  |        ubuntu_20_04         | The Operating system of the node                        |
|    billing_cycle       | string  |           hourly            | How the node will be billed (Not usually changed)       |
|     cluster_name       | string  |  equinix-metal-gke-cluster  | The name of the GKE cluster                             |
|    create_project      | string  |           true              | Create a new project for this deployment?               |
|     project_name       | string  |       baremetal-anthos      | The name of the project if 'create_project' is 'true'.  |
|        bgp_asn         | string  |            65000            | BGP ASN to peer with Equinix Metal                      |
|      ccm_version       | string  |           v2.0.0            | The version of the Equinix Metal CCM                    |
|    kube_vip_version    | string  |            0.2.3            | The version of Kube-VIP to install                      |
|      anthos_version    | string  |            1.6.0            | The version of Google Anthos to install                 |
|     ccm_deploy_url     | string  | **Too Long to put here...** | The deploy url for the Equinix Metal CCM                |
| kube_vip_daemonset_url | string  | **Too Long to put here...** | The deploy url for the Kube-VIP Daemonset               |

#### Supported Operating Systems
|            Name            |   Api Slug   |
| :------------------------: | :----------: |
|          CentOS 8          |   centos_8   |
|        Ubuntu 18.04        | ubuntu_18_04 |
|        Ubutnu 20.04        | ubuntu_20_04 |

##### Comming Soon
|           Name             |   Api Slug   |
| :-----------------------:  | :----------: |
| Red Hat Enterprise Linux 8 |    rhel_8    |


## Deploy the Anthos on Baremetal cluster onto Equinix Metal 
 
All there is left to do now is to deploy the cluster: 
```bash 
terraform apply --auto-approve 
``` 
This should end with output similar to this: 
``` 
Apply complete! Resources: 28 added, 0 changed, 0 destroyed.

Outputs:

Control_Plane_Public_IPs = [
  "136.144.50.115",
  "136.144.50.117",
  "136.144.50.119",
]
Control_Plane_VIP = "145.40.65.107"
Ingress_VIP = "145.40.65.106"
Kubeconfig_location = "/home/cloud-user/git/baremetal-anthos/equinix-metal-gke-cluster-vomqb-kubeconfig"
Worker_Public_IPs = [
  "136.144.50.123",
  "145.40.64.221",
  "136.144.50.105",
]
ssh_key_location = "/home/cloud-user/.ssh/bm-cluster-20201211211054"
```

You can see this output again at anytime by running `terraform output`


## Use an existing Equinix Metal project
If you have an existing Equinix Metal project you can use it.
**YOU MUST ENABLE BGP PEERING ON YOUR PROJECT WITHOUT A PASSWORD**

Get your Project ID, navigate to the Project from the console.equinixmetal.com console and click on PROJECT SETTINGS, copy the PROJECT ID.

add the following variables to your terraform.tfvars

```
create_project                    = false
project_id                        = "YOUR-PROJECT-ID"
```

## Google Anthos Documentation
Once Anthos is deployed on Equinix Metal, all of the documentation for using Google Anthos is located on the [Anthos Documentation Page](https://cloud.google.com/anthos/docs).

