#!/bin/bash
OS='${operating_system}'
IP_ADDRESS='${ip_address}'
NETMASK='${netmask}'


function rhel_config {
    nic=`ip a | grep "master bond0" | tail -1 | awk '{print $2}' | awk -F':' '{print $1}'`
    ifdown $nic
    cat <<-EOF > /etc/sysconfig/network-scripts/ifcfg-$nic
        DEVICE=$nic
        ONBOOT=yes
        BOOTPROTO=none
        IPADDR=$IP_ADDRESS
        NETMASK=$NETMASK
EOF
    ifup $nic
}


function ubuntu_config {
    nic=`grep auto /etc/network/interfaces | tail -1 | awk '{print $2}'`
    ifdown $nic
    head -n -5 /etc/network/interfaces > /etc/network/interfaces
    printf "\nauto $nic\n" >> /etc/network/interfaces
    printf "iface $nic inet static\n" >> /etc/network/interfaces
    printf "\taddress $IP_ADDRESS\n" >> /etc/network/interfaces
    printf "\tnetmask $NETMASK\n" >> /etc/network/interfaces
    ifup $nic
}


function unknown_config {
    echo "I don't konw who I am" > /root/who_am_i.txt
}


if [ "$${OS:0:6}" = "centos" ] || [ "$${OS:0:4}" = "rhel" ]; then
    rhel_config
elif [ "$${OS:0:6}" = "ubuntu" ]; then
    ubuntu_config
else
    unknown_config
fi
