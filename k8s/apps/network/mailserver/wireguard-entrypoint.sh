#!/bin/sh

set -ex

if [ -z "$GATEWAY_IP" ]; then echo "GATEWAY_IP env var is required"; exit 255; fi
if [ ! -f /etc/os-release ]; then echo "Could not identify distribution"; exit 255; fi
if [ ! -f /etc/wireguard/wg0.conf ]; then echo "/etc/wireguard/wg0.conf is required"; exit 255; fi

if ip addr | grep -q wg0; then
    ip link del wg0
else
    . /etc/os-release

    case $ID in
        alpine)
            apk update
            apk add wireguard-tools curl
            ;;
        *)
            echo "This distribution is not supported"
            exit 255
            ;;
    esac

    K8S_GW_IP=$(/sbin/ip route | awk '/default/ { print $3 }')

    # command might fail if rule already set
    ip route add "$GATEWAY_IP" via "$K8S_GW_IP" || /bin/true
    for local_cidr in "10.0.0.0/8" "172.16.0.0/12" "192.168.0.0/24"; do
        ip route add "$local_cidr" via "$K8S_GW_IP" || /bin/true
    done
fi

echo "Deleting existing default GWs"
ip route del 0/0 || /bin/true

echo "Network config after clean up:"
ip addr
ip route

# Check we can connect to the GATEWAY IP
ping -c 10 "$GATEWAY_IP"

# Create tunnel NIC
ip link add wg0 type wireguard
wg setconf /etc/wireguard/wg0.conf
ip link set up dev wg0

echo "Network config after Wireguard setup:"
ip addr
ip route

if [ "$(curl ipconf.co)" -ne "$GATEWAY_IP" ]; then
    echo "Traffic is not being forwarded propery through gateway - check gateway NAT config"
    exit 255
fi

echo "Gateway ready and reachable"

while true; do
    sleep 9999999999d
done
