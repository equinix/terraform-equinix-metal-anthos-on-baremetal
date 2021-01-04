#!/bin/bash
distro=$(lsb_release -i -s | tr A-Z a-z)
case $distro in
  ubuntu|debian)
    export DEBIAN_FRONTEND=noninteractive
    apt update -q
    apt install -qy systemd-timesyncd
    apt autoremove -qy
    ;;
  centos|redhatenterprise)
    dnf install jq -y
    ;;
esac

GATEWAY_IP=$(curl https://metadata.platformequinix.com/metadata | jq -r ".network.addresses[] | select(.public == false) | .gateway")
sed -i.bak -E "/^\s+post-down route del -net 10\.0\.0\.0.* gw .*$/a \ \ \ \ up ip route add 169.254.255.1 via $GATEWAY_IP || true\n    up ip route add 169.254.255.2 via $GATEWAY_IP || true\n    down ip route del 169.254.255.1 || true\n    down ip route del 169.254.255.2 || true" /etc/network/interfaces
ip route add 169.254.255.1 via $GATEWAY_IP
ip route add 169.254.255.2 via $GATEWAY_IP
