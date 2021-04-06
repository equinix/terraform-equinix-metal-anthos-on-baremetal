#!/bin/bash
OS='${operating_system}'

function ubuntu_pre_reqs {
    sudo systemctl stop apparmor
    sudo systemctl disable apparmor
    sudo systemctl stop ufw
    sudo systemctl disable ufw
    
}

function rhel_pre_reqs {
    # Disable Firewalld
    sudo systemctl disable firewalld
    sudo systemctl stop firewalld
    # Disable SELinux
    sudo setenforce 0
    dnf install jq -y
}

function bgp_routes {
    GATEWAY_IP=$(curl https://metadata.platformequinix.com/metadata | jq -r ".network.addresses[] | select(.public == false) | .gateway")
    sed -i.bak -E "/^\s+post-down route del -net 10\.0\.0\.0.* gw .*$/a \ \ \ \ up ip route add 169.254.255.1 via $GATEWAY_IP || true\n    up ip route add 169.254.255.2 via $GATEWAY_IP || true\n    down ip route del 169.254.255.1 || true\n    down ip route del 169.254.255.2 || true" /etc/network/interfaces
    ip route add 169.254.255.1 via $GATEWAY_IP
    ip route add 169.254.255.2 via $GATEWAY_IP
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

bgp_routes