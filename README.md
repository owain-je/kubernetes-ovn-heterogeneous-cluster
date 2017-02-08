# Heterogeneous Kubernetes cluster on top of OVN

**Author**: Paulo Pires <pires@apprenda.com>

This document describes, step-by-step, how to provision a Kubernetes cluster comprised of:
* One Linux machine acting as Kubernetes master node and OVN central database.
* One Linux machine acting as Kubernetes worker node.
* One Windows machine acting as Kubernetes worker node.

Many thanks to the great people that helped achieve this, namely:
* Alin Serdean (Cloudbase Solutions)
* Alin Balutoiu (Cloudbase Solutions)
* Feng Min (Google)
* Peter Hornyack (Google)

## Requirements

* Use Google Cloud Platform (GCP) , namely Google Compute Engine (GCE) VMs.
  * `gcloud` CLI tool
* Linux machines(s) run Ubuntu 16.04 with latest updates.
* Windows machine(s) run Windows Server 2016 with latest updates.
* Administrator access to all VMs, i.e. `root` in Linux machines.

## Master (Linux)

### Node set-up

Let's provision the master VM:
```sh
gcloud compute instances create "sig-windows-master" \
    --zone "us-east1-d" \
    --machine-type "custom-2-2048" \
    --subnet "default" \
    --can-ip-forward \
    --maintenance-policy "MIGRATE" \
    --tags "http-server","https-server" \
    --image "ubuntu-1604-xenial-v20170125" \
    --image-project "ubuntu-os-cloud" \
    --boot-disk-size "50" \
    --boot-disk-type "pd-ssd" \
    --boot-disk-device-name "sig-windows-master"
```

When it's ready, SSH into it:
```sh
gcloud compute ssh --zone "us-east1-d" "sig-windows-master"
```

**ATTENTION**: From now on, it's assumed you're logged-in as `root`.

Since we'll need Docker, let's install it:
```sh
curl -fsSL https://yum.dockerproject.org/gpg | apt-key add -
echo "deb https://apt.dockerproject.org/repo ubuntu-xenial main" > sudo tee /etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y docker.io
```

We also need to download the contents of this repository which will be used shortly:
```sh
cd ~
git clone https://github.com/apprenda/kubernetes-ovn-heterogeneous-cluster
cd kubernetes-ovn-heterogeneous-cluster/deb

dpkg -i openvswitch-common_2.6.2-1_amd64.deb \
openvswitch-datapath-dkms_2.6.2-1_all.deb \
openvswitch-switch_2.6.2-1_amd64.deb \
ovn-common_2.6.2-1_amd64.deb \
ovn-central_2.6.2-1_amd64.deb \
ovn-docker_2.6.2-1_amd64.deb \
ovn-host_2.6.2-1_amd64.deb \
python-openvswitch_2.6.2-1_all.deb
```

Finally, reboot:
```sh
reboot
```

SSH again into the machine and let's proceed.

**TODO** is this still needed after the reboot?
```
rmmod openvswitch
insmod /lib/modules/$(uname -r)/updates/dkms/openvswitch.ko
modprobe vport-geneve
```

Create the OVS bridge interface:
```sh
ovs-vsctl add-br br-int

export TUNNEL_MODE=geneve
export LOCAL_IP=10.142.0.2
export MASTER_IP=10.142.0.2 

ovs-vsctl set Open_vSwitch . external_ids:ovn-remote="tcp:$MASTER_IP:6642" \
  external_ids:ovn-nb="tcp:$MASTER_IP:6641" \
  external_ids:ovn-encap-ip="$LOCAL_IP" \
  external_ids:ovn-encap-type="$TUNNEL_MODE"

ovs-vsctl get Open_vSwitch . external_ids
```

You should see something like:
```
{hostname=sig-windows-master.c.apprenda-project-one.internal, "k8s-api-server"="127.0.0.1:8080", ovn-encap-ip="10.142.0.2", ovn-encap-type=geneve, ovn-nb="tcp:10.142.0.2:6641", ovn-remote="tcp:10.142.0.2:6642", system-id="e7af27f6-a218-40bb-8d4f-af67600abd17"}
```

We are now ready to set-up Kubernetes master node.

### Kubernetes set-up

**ATTENTION**: From now on, it's assumed you're logged-in as `root`.

First, we need to run `etcd`, the store used by Kubernetes. The following is a one-time step only:
```sh
cd ~/kubernetes-ovn-heterogeneous-cluster/master
cp -R systemd/*.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable etcd3
systemctl start etcd3
```

Then, proceed to set-up Kubernetes:
```sh
./make-certs

mkdir -p /etc/kubernetes
cp -R manifests /etc/kubernetes/

systemctl enable kubelet
systemctl start kubelet

curl -Lskj -o /usr/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/v1.5.2/bin/linux/amd64/kubectl
chmod +x /usr/bin/kubectl

kubectl config set-cluster default-cluster --server=https://10.142.0.2 --certificate-authority=/etc/kubernetes/tls/ca.pem
kubectl config set-credentials default-admin --certificate-authority=/etc/kubernetes/tls/ca.pem --client-key=/etc/kubernetes/tls/admin-key.pem --client-certificate=/etc/kubernetes/tls/admin.pem
kubectl config set-context local --cluster=default-cluster --user=default-admin
kubectl config use-context local

kubectl create -f ../kubedns-deployment.yaml
kubectl create -f ../kubedns-service.yaml
```

Last step is to configure pod networking for this node:
```sh
ovs-vsctl set Open_vSwitch . external_ids:k8s-api-server="127.0.0.1:8080"

apt-get install -y python-pip
cd ~
git clone https://github.com/openvswitch/ovn-kubernetes
cd ovn-kubernetes
pip install --prefix=/usr/local .

ovn-k8s-overlay master-init \
  --cluster-ip-subnet="10.244.0.0/16" \
  --master-switch-subnet="10.244.1.0/24" \
  --node-name="10.142.0.2"

systemctl enable ovn-k8s-watcher
systemctl start ovn-k8s-watcher
```

By this time, your master node is ready:
```
kubectl get nodes
kubectl -n kube-system get pods
```

Let's proceed to set-up the worker nodes.

## Worker (Linux)

### Node set-up

**TODO**

## Worker (Windows)

**TODO**

## (Optional) Build packages

### OVS/OVN

As `root`, run:
```
apt-get update
apt-get install -y build-essential fakeroot dkms \
autoconf automake debhelper dh-autoreconf libssl-dev libtool \
python-all python-twisted-conch python-zopeinterface \
graphviz

cd ~
git clone https://github.com/openvswitch/ovs.git
cd ovs
git checkout branch-2.6

dpkg-checkbuilddeps

DEB_BUILD_OPTIONS='nocheck' fakeroot debian/rules binary
```

## TODO

- [ ] `etcd` container should use a host path for storing data, in order to survive restarts.
- [ ] Automate certificate generation based on node type and IP.
- [ ] Template all the things.
- [ ] Add other cloud providers documentation, e.g. AWS.
- [ ] Add gateway node instructions for enabling pod containers Internet access.