# Provisioning a heterogeneous kubernetes cluster on Google Cloud Platform


This document describes an automated way to provision and configure a Kubernetes cluster comprised of:

* One Linux machine acting as Kubernetes master node and OVN central database.
* One Linux machine acting as Kubernetes worker node.
* One Windows machine acting as Kubernetes worker node.
* One Linux machine acting as gateway node.

It is essentially the same as the main demo at [kubernetes-ovn-heterogeneous-cluster](https://github.com/apprenda/kubernetes-ovn-heterogeneous-cluster/), but scripted out for an easier and quicker setup.  Typical automated provisioning and configuration of a heterogeneous cluster as described above using this method takes around 20 -30 minutes.  It has been kept as bash and powershell for easy reading/modification. 


## Requirements
* A Linux machine to run the provisioning script from
* The Google Cloud CLI tool [gcloud](https://cloud.google.com/sdk/gcloud/) installed and initialized
* [git](https://git-scm.com/) to pull this repository locally


## Instructions

First, pull this repository locally using git

    git clone https://github.com/apprenda/kubernetes-ovn-heterogeneous-cluster.git

Then modify the config file found at `kubernetes-ovn-heterogeneous-cluster/provisioning/gce/provisioning.conf` if desired, though the defaults will work for most cases.

The provisioning script takes two arguments, the compute engine zone to provision the nodes in, and a prefix to add to the node names.  

     cd kubernetes-ovn-heterogeneous-provisioning/gce/     
     ./provision.sh -z us-east1-b -p test

This will provision the following nodes in the `us-east1-b` zone

|Node Name |OS| Description|
|----|--------|------------|
|test-master|Linux|Kubernetes master node and OVN central database|
|test-worker-linux-1|Linux|Kubernetes worker node|
|test-worker-windows-1|Windows|Kubernetes worker node|
|test-gw|Linux|Gateway node|

Along with provisioning the nodes, the script will install and configure Kubernetes and Open vSwitch on both the Linux and Windows nodes.

Linux nodes are provisioned with the tag `nodeport-allow`, which can be used to setup Google Cloud Firewall rules allowing external access to the nodes (currently only the gateway node is supported).  Information about firewall rules on Google Cloud can be found [here](https://cloud.google.com/compute/docs/vpc/firewalls)

**Note, after the script has completed, the Windows node will reboot a number of times while configuration is taking place.  Also of note, part of this configuration is disabling the Windows firewall.**

You can determine when the windows node configuration is complete by running the following from the master node:

    watch kubectl get nodes

Once the windows node shows up as Ready, it has completed the configuration step, and your cluster should be good to go.  
If you need to rdp to your windows node, you may find instructions on how to RDP into the Windows machine [here](https://cloud.google.com/compute/docs/instances/windows/connecting-to-windows-instance).


You can then head over to the [demo page](https://github.com/apprenda/kubernetes-ovn-heterogeneous-cluster/tree/master/demo) for instructions on deploying a Windows workload.




