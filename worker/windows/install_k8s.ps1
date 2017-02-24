$PUBLIC_IP="10.142.0.9"
$HOSTNAME=hostname
$KUBERNETES_API_SERVER="10.142.0.2"
$CLUSTER_IP_SUBNET="10.244.0.0/16"
$K8S_PATH="C:\kubernetes"

mkdir $K8S_PATH
cd $K8S_PATH

# Instal 7z so we can extract Kubernetes binaries
Start-BitsTransfer http://www.7-zip.org/a/7z1604-x64.exe
cmd /c 'C:\kubernetes\7z1604-x64.exe /qn'
Remove-Item -Recurse -Force 7z1604-x64.exe

# Download and extract Kubernetes binaries
Start-BitsTransfer https://dl.k8s.io/v1.5.3/kubernetes-node-windows-amd64.tar.gz
cmd /c '"C:\Program Files\7-Zip\7z.exe" e kubernetes-node-windows-amd64.tar.gz'
cmd /c '"C:\Program Files\7-Zip\7z.exe" x kubernetes-node-windows-amd64.tar'
mv kubernetes\node\bin\*.exe .
Remove-Item -Recurse -Force kubernetes
Remove-Item -Recurse -Force kubernetes-node-windows-amd64*

# TODO register kube-proxy as a service and start it
#$env:INTERFACE_TO_ADD_SERVICE_IP = "Ethernet"
#.\kube-proxy.exe --proxy-mode=userspace --hostname-override=$HOSTNAME-$PUBLIC_IP --bind-address=$PUBLIC_IP --master=https://$KUBERNETES_API_SERVER #--kubeconfig=C:\kubernetes\node-kubeconfig.yaml --cluster-cidr=$CLUSTER_IP_SUBNET

# TODO register kubelet as a service and start it
#$env:CONTAINER_NETWORK = "external"
#.\kubelet.exe -v=3 --address=10.142.0.9 --hostname-override=10.142.0.9 --cluster_dns=10.100.0.10 --cluster_domain=cluster.local --pod-infra-container-image="apprenda/pause" --resolv-conf="" --api_servers=https://10.142.0.2 --kubeconfig=C:\kubernetes\node-kubeconfig.yaml --tls-cert-file=C:\kubernetes\tls\node.pem --tls-private-key-file=C:\kubernetes\tls\node-key.pem