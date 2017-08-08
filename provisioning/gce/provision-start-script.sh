#!/bin/bash

#This script does the initial setup that is common to all Linux nodes in the cluster.
#Once it is complete, it will create the /setup file, which will prevent the script from doing the initial setup on reboot.
#It will then perform the required reboot, and on startup, on seeing the /setup file, it will create the /ready file, which
#will tell the provisioning script that the node is ready.

if [[ -f "/setup" ]]; then
    touch /ready
    exit 0
fi

# Make sure cert group exists
groupadd -r kube-cert
mkdir -p /etc/kubernetes/tls
chown root:kube-cert /etc/kubernetes/tls
chmod 775 /etc/kubernetes/tls


#OVS/OVN Installation
curl -fsSL https://yum.dockerproject.org/gpg | apt-key add -
echo "deb https://apt.dockerproject.org/repo ubuntu-xenial main" > sudo tee /etc/apt/sources.list.d/docker.list

apt update
apt install -y docker.io dkms

cd ~
git clone https://github.com/apprenda/kubernetes-ovn-heterogeneous-cluster
cd kubernetes-ovn-heterogeneous-cluster/deb

dpkg -i openvswitch-common_2.7.2-1_amd64.deb \
openvswitch-datapath-dkms_2.7.2-1_all.deb \
openvswitch-switch_2.7.2-1_amd64.deb \
ovn-common_2.7.2-1_amd64.deb \
ovn-central_2.7.2-1_amd64.deb \
ovn-docker_2.7.2-1_amd64.deb \
ovn-host_2.7.2-1_amd64.deb \
python-openvswitch_2.7.2-1_all.deb

echo vport_geneve >> /etc/modules-load.d/modules.conf

touch /setup
echo "Rebooting system now."
reboot
