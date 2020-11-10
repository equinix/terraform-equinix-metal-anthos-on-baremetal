#!/bin/bash
operating_systems=('ubuntu_18_04' 'ubuntu_20_04' 'centos_8' 'rhel_8')

if [ "$1" = "apply" ]; then
    for os in "${operating_systems[@]}"; do
        mkdir -p $os
        short_name=`echo $os |sed "s/_//g"`
        nohup terraform apply --auto-approve -state="./$os/terraform.tfstate" -var "operating_system=$os" -var "facility=sv15" -var "plan=c3.small.x86" -var "hostname=$short_name-anothos-baermetal" > ./$os/terraform.log &
    done
elif [ "$1" = "destroy" ]; then
    for os in "${operating_systems[@]}"; do
        terraform destroy --auto-approve -state="./$os/terraform.tfstate"
        rm -rf $os
    done
else
    echo 'Command line arg "apply" or "destroy" is required! Exiting!'
fi
