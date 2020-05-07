# Anthos Baremetal on Packet
This is a very basic terraform template that will deploy ***N*** number of nodes (Defaults to 2) and configure a private vLan and IPs between these nodes using Packet's ***Mixed/Hybrid*** networking. This has been tested with Ubuntu 18.04 and CentOS7 and ***should*** work with: Ubuntu 16.04, CentOS 8, RHEL 7, & RHEL 8.
## Install Terraform 
Terraform is just a single binary.  Visit their [download page](https://www.terraform.io/downloads.html), choose your operating system, make the binary executable, and move it into your path. 
 
Here is an example for **macOS**: 
```bash 
curl -LO https://releases.hashicorp.com/terraform/0.12.18/terraform_0.12.18_darwin_amd64.zip 
unzip terraform_0.12.18_darwin_amd64.zip 
chmod +x terraform 
sudo mv terraform /usr/local/bin/ 
``` 
 
## Download this project
To download this project, run the following command:

```bash
git clone https://github.com/c0dyhi11/baremetal-anthos.git
cd baremetal-anthos
```

## Initialize Terraform 
Terraform uses modules to deploy infrastructure. In order to initialize the modules your simply run: `terraform init`. This should download modules into a hidden directory `.terraform` 
 
## Modify your variables 
You will need to set three variables at a minimum and there are a lot more you may wish to modify in `variables.tf`
```bash 
cat <<EOF >terraform.tfvars 
auth_token = "cefa5c94e8ee4577bff81d1edca93ed8" 
project_id = "42259e34-d300-48b3-b3e1-d5165cd14169" 
EOF 
``` 

## Deploy terraform template
```bash
terraform apply --auto-approve
```
Once this is complete you should get output similar to this:
```
Apply complete! Resources: 5 added, 0 changed, 0 destroyed.

Outputs:

Hostnames = [
  "anthos-baremetal-01",
  "anthos-baremetal-02",
]
Public_IPs = [
  "147.75.69.143",
  "147.75.70.22",
]
Tags = [
  [
    "anthos",
    "baremetal",
    "192.168.1.1",
  ],
  [
    "anthos",
    "baremetal",
    "192.168.1.2",
  ],
]
```

## Tested Operating Systems

| Name | Api Slug |
| :--: |:-------: |
| CentOS 7 | centos_7 |
| CentOS 8 | centos_8 |
| RedHat Enterprise Linux 7 | rhel_7 |
| RedHat Enterprise Linux 8 | rhel_8 |
| Ubuntu 16.04 | ubuntu_16_04 |
| Ubuntu 18.04 | ubuntu_18_04 |
| Ubutnu 20.04 | ubuntu_20_04 |

## Variables
| Variable Name | Type | Default Value | Description |
| :-----------: |:---: | :------------:|:------------|
| auth_token | string | n/a | Packet API Key |
| project_id | string | n/a | Packet Project ID |
| hostname | string | anthos-baremetal | The hostname for nodes |
| facility | string | sjc1 | Packet  Facility  to  deploy  into |
| plan | string | c2.medium.x86 | Packet  device  type  to  deploy |
| node_count | number | 2 | Number  of  baremetal  nodes |
| operating_system | string | ubuntu_18_04 | The  Operating  system  of  the  node |
| billing_cycle | string | hourly | How  the  node  will  be  billed (Not  usually  changed) |
| private_subnet | string | 192.168.1.0/24 | Private  IP  Space  to  use  for  Layer2 |

## Testing script
I had the need to see if my terraform script would work on each operating system. So I wrote ***test_matrix.sh*** to handle this for me. This script has a bunch of operating systems in a list and will execute the terraform scripts into folder for each OS. The output of the terraform script is stored in that dedicated directory in a file called terraform.log.

To run this script simply do the following:
```bash
./test_matrix.sh apply
```
Once you are finished, you can tear it all down as follows:
```bash
./test_matrix.sh destroy
```

Enjoy!

