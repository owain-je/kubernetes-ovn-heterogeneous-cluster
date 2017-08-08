#!/bin/bash

function usage() {
    echo "Usage: provision -p prefix -u user -z zone"
    echo
    echo "Options:"
    echo "-p | --prefix : A prefix to be prepended to GCE instance names"
    echo "-z | --zone : GCE zone to provision instances into"
    echo "-h | --help : display help"
    exit 1
}


prefix=
user=sig-win
zone=

while true; do
  case "$1" in
    -p | --prefix ) prefix="$2"; shift ;;
    -u | --user   ) user="$2"; shift ;;
    -z | --zone   ) zone="$2"; shift ;;
    -h | --help ) usage;;
    -- ) shift; break ;;
        -*) echo "ERROR: unrecognized option $1"; exit 1;;
    * ) break ;;
  esac
  shift
done

if [ -z "${prefix}" ]; then 
	echo "prefix is required parameter"
	usage
fi

if [ -z "${zone}" ]; then 
	echo "zone is a required parameter"
	usage
fi


#Generate SSH key, used for K8S cert transfers between nodes.
function generateSSHKey() {	

	local hostname=$1
	local user=$2

	echo "$(date): Generating SSH Key for user ${user} on instance ${hostname}"

	local connected="false"

	while [ "${connected}" == "false" ]; do
		if gcloud compute ssh --zone ${zone} ${hostname} --command="sudo useradd -m -G kube-cert ${user} && sudo mkdir -p /home/${user}/.ssh && sudo ssh-keygen -t rsa -f /home/${user}/.ssh/gce_rsa -C ${user} -q -N ''"; then
			connected="true"
		else 
			echo "$(date): Could not connect to ${hostname}...this may be expected if it was just provisioned."
			echo "Sleeping 5s..."
			sleep 5
		fi
	done

}

#Pulls public key from host.  Used for K8S cert transfers between nodes.
function getPublicKey() {

	local hostname=$1
	local user=$2

	echo "$(date): Pulling the public key from ${hostname}"

	gcloud compute scp --zone ${zone} ${hostname}:/home/${user}/.ssh/gce_rsa.pub ${hostname}.pub
}

#Provisions the linux node
function provision_linux() {
	
	local instance=$1
	local zone=$2
	local startupScript=$3

	echo "$(date): Provisioning linux instance ${instance} in zone ${zone} with startup script ${startupScript}"

	gcloud compute instances create "${instance}" \
	    --zone "${zone}" \
	    --machine-type "custom-2-2048" \
	    --can-ip-forward \
	    --tags "https-server" \
   	    --tags "nodeport-allow" \
	    --image-family "ubuntu-1604-lts" \
	    --image-project "ubuntu-os-cloud" \
	    --boot-disk-size "50" \
	    --boot-disk-type "pd-ssd" \
	    --metadata-from-file startup-script="${startupScript}"


    echo "$(date): Waiting for instance start-provisioning script to complete."
    #The startup script will write empty file at /ready once it has completed.
    local isReady="false"

    while [ "${isReady}" == "false" ]; do
        if gcloud compute ssh -q --zone ${zone} ${instance} --command "stat /ready > /dev/null 2>&1" > /dev/null 2>&1 ; then
            	isReady="true"
        else
            printf "."
            sleep 5
        fi
    done
    printf "done\n"
}

#Provisions the windows node.
function provision_windows() {

    local instance=$1
    local zone=$2
    local startupScript=$3
    local apiServerIp=$4

    echo "$(date): Provisioning windows instance ${instance} in zone ${zone} with startup script ${startupScript}"
    gcloud compute instances create "${instance}" \
        --zone "${zone}" \
        --machine-type "custom-4-4096" \
        --can-ip-forward \
        --image-family "windows-2016" \
        --image-project "windows-cloud" \
        --boot-disk-size "50" \
        --boot-disk-type "pd-ssd" \
        --metadata-from-file windows-startup-script-ps1="${startupScript}" \
        --metadata apiServer="${apiServerIp}"

    echo "$(date): The windows node will reboot a few times during the course of configuration.  Please allow 5-10 minutes for the node to be fully configured.  \
    During this time, you can reset the rdp password, and connect, though you may be disconnected due to reboots"
}

#Modifies the public key to match the format expected by GCE
function modifyPublicKey() {

	local hostname=$1
	local user=$2
	local combinedPKFile=$3

	echo "$(date): Fixing format of the ${hostname} public key to match GCE expectations, and adding to ${combinedPKFile}"

	sed -i -e "s/^/${user}:/" ./${hostname}.pub
	cat ./${hostname}.pub >> ${combinedPKFile}
}


#Copies the local config file to the node.
function copyConfigFile() {
	local instance=$1
	local configFile=$2

	echo "$(date): Copying config file '${configFile}' to instance ${instance}"

	gcloud compute scp --zone ${zone} ${configFile} ${instance}:/tmp
	gcloud compute ssh --zone ${zone} ${instance} --command "sudo mv /tmp/${configFile} /root/kubernetes-ovn-heterogeneous-cluster/${configFile}"
}

#Runs the configuration script that sets up the node.
function configureNode() {
	local instance=$1
	local masterIp=$2
	local localIp=$3
	local nodeType=$4

    echo "$(date): Configuring node ${instance} as ${nodeType} node"

	gcloud compute ssh --zone ${zone} ${instance} --command "sudo chown -R ${user}:${user} /home/${user}/.ssh/"
	gcloud compute ssh --zone ${zone} ${instance} --command "sudo -H /root/kubernetes-ovn-heterogeneous-cluster/provisioning/gce/configure-node.sh ${masterIp} ${localIp} ${nodeType}"

}

#Provisions the node, adds ssh key for transferring K8S certs between nodes, and copies the config file to the node.
function setupNode() {

	local instance=$1
	local user=$2
	local zone=$3
	local combinedPkFile=$4
	local configFile=$5


	echo "$(date): Starting initial setup for ${instance}..."
	printf "==========================================================\n\n"

	provision_linux "${instance}" "${zone}" "./provision-start-script.sh"
	sleep 10
	generateSSHKey "${instance}" "${user}"
	getPublicKey "${instance}" "${user}"
	modifyPublicKey "${instance}" "${user}" "${combinedPKFile}"
	copyConfigFile ${instance} ${configFile}
	echo "$(date): Completed initial setup for ${instance}."
	printf "==========================================================\n\n"
}

cwd=$(pwd)
combinedPKFile="${cwd}/combined.pub"
configFile="provisioning.conf"

if [[ -f ${combinedPKFile} ]]; then
	rm ${combinedPKFile}
fi

printf "$(date): Starting provisioning of heterogenous Kubernetes cluster on Google Cloud Platform.\n"

for i in "master" "worker-linux-1" "gw"; do
	instance="${prefix}-${i}"
	setupNode ${instance} ${user} ${zone} ${combinedPKFile} ${configFile}
done

#Configure the master node
instance="${prefix}-master"
echo "$(date): Configuring ${instance}..."
printf "==========================================================\n\n"

masterExternalIp=$(gcloud compute instances describe --zone ${zone} ${instance} | grep networkIP | sed 's/\s*networkIP:\s*//')

echo "$(date): Adding public keys to authorized host of ${instance}"
#Set the metadata element from combined file
gcloud compute instances add-metadata --zone ${zone} ${instance} --metadata-from-file ssh-keys=${cwd}/combined.pub

rm ${instance}.pub

configureNode ${instance} ${masterExternalIp} ${masterExternalIp} "master"

#Configure the linux worker node
instance="${prefix}-worker-linux-1"
echo "$(date): Configuring ${instance}..."
printf "==========================================================\n\n"
workerExternalIp=$(gcloud compute instances describe --zone ${zone} ${instance} | grep networkIP | sed 's/\s*networkIP:\s*//')

echo "$(date): Adding public keys to authorized host of ${instance}"
#Set the metadata element from combined file
gcloud compute instances add-metadata --zone ${zone} ${instance} --metadata-from-file ssh-keys=${cwd}/combined.pub

rm ${instance}.pub

configureNode ${instance} ${masterExternalIp} ${workerExternalIp} "worker/linux"

#Configure the gateway node
instance="${prefix}-gw"
echo "$(date): Configuring ${instance}..."
printf "==========================================================\n\n"
gatewayExternalIp=$(gcloud compute instances describe --zone ${zone} ${instance} | grep networkIP | sed 's/\s*networkIP:\s*//')

echo "$(date): Adding public keys to authorized host of ${instance}"
#Set the metadata element from combined file
gcloud compute instances add-metadata --zone ${zone} ${instance} --metadata-from-file ssh-keys=${cwd}/combined.pub

rm ${instance}.pub
configureNode ${instance} ${masterExternalIp} ${gatewayExternalIp} "gateway"

rm combined.pub

#Windows setup
instance="${prefix}-worker-windows-1"
echo "$(date): Starting initial setup for ${instance}..."
printf "==========================================================\n\n"
provision_windows "${instance}" "${zone}" "./windows-provision-start-script.ps1" ${masterExternalIp}

