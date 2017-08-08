#!/bin/bash

#This script uses the config values from provisioning.conf, which combined with the nodes template file, produce the script
#To complete the setup and configuration of the node.

ROOT_CHECKOUT_DIR="/root/kubernetes-ovn-heterogeneous-cluster/"; export ROOT_CHECKOUT_DIR

config=${ROOT_CHECKOUT_DIR}/provisioning.conf

if [[ ! -f  ${config} ]]; then 
	echo "Required config file '${config}' is not present'"
	exit 1
fi

#Read the config values from the file and export them.
set -a 
source ${config}
set +a 

MASTER_IP=$1; export MASTER_IP
LOCAL_IP=$2; export LOCAL_IP
nodeType=$3; export nodeType

#These values are variables in the template script, so store the variable name as the value to prevent losing the vars.
TOKEN="\$TOKEN"; export TOKEN
NIC="\$NIC"; export NIC
GW_IP="\$GW_IP"; export GW_IP

HOSTNAME=`hostname`; export HOSTNAME

echo "Configuring node on ${HOSTNAME}"

pathToTemplate=

if [[ ${nodeType} == "master" ]]; then
	    pathToTemplate=${ROOT_CHECKOUT_DIR}/master
elif [[ ${nodeType} == "worker/linux" ]]; then
        pathToTemplate=${ROOT_CHECKOUT_DIR}/worker/linux
elif [[ ${nodeType} == "gateway" ]]; then
        pathToTemplate=${ROOT_CHECKOUT_DIR}/gateway
else 
	echo "Invalid node type '${nodeType}', expecting 'master', 'worker/linux', or 'gateway'"
	exit 1
fi

#Use the template file, and the config file to generate the script with the configured values to configure the node.
envsubst < ${pathToTemplate}/configure.sh-template > ${pathToTemplate}/configure.sh

#Mark as executable and run the script.
chmod +x ${pathToTemplate}/configure.sh
${pathToTemplate}/configure.sh
