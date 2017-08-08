#!/bin/bash

NIC=$1

if [ -z "${NIC}" ]; then
    echo "usage: check-ovn-k8s-network.sh nic"
    exit -1
fi

if ovs-vsctl br-exists br${NIC} ; then
	ovs-vsctl del-br br${NIC}
fi

ovn-k8s-util nics-to-bridge ${NIC} && dhclient br${NIC}

