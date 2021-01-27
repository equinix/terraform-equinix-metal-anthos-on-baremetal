#!/usr/bin/env bash
OS='${operating_system}'

function ubuntu_pre_reqs {
    # Install Docker
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get update -qy
    sudo apt-get install -qy lvm2
}


function rhel_pre_reqs {
    sudo dnf install lvm2 -y
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
