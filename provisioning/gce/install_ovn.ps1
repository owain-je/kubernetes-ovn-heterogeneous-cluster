
$SUBNET="10.111.12.0/24" # The minion subnet used to spawn pods on
$GATEWAY_IP="10.111.12.1" # first ip of the subnet
$CLUSTER_IP_SUBNET="10.111.0.0/16" # The big subnet which includes the minions subnets
$INTERFACE_ALIAS="Ethernet" # Interface used for creating the overlay tunnels (must have connectivity with other hosts)
$KUBERNETES_API_SERVER=$env:K8S_MASTER_IP
#Invoke-RestMethod -URI http://metadata.google.internal/computeMetadata/v1/instance/attributes/apiServer -Headers @{"Metadata-Flavor" = "Google"}  # API kubernetes server IP
$PUBLIC_IP=(Get-NetIPConfiguration | Where-Object {$_.InterfaceAlias -eq "Ethernet"}).IPv4Address.IPAddress

$HOSTNAME=hostname
$K8S_ZIP=".\k8s_ovn_service_prerelease.zip" # Location of k8s OVN binaries (DO NOT CHANGE unless you know what you're doing)
$OVS_PATH="c:\Program Files\Cloudbase Solutions\Open vSwitch\bin" # Default installation directory for OVS (DO NOT CHANGE unless you know what you're doing)

Stop-Service docker
Get-ContainerNetwork | Remove-ContainerNetwork -Force
cmd /c 'echo { "bridge" : "none" } > C:\ProgramData\docker\config\daemon.json'
Start-Service docker

docker network create -d transparent --gateway $GATEWAY_IP --subnet $SUBNET -o com.docker.network.windowsshim.interface=$INTERFACE_ALIAS external

$a = Get-NetAdapter | where Name -Match HNSTransparent
rename-netadapter $a[0].name -newname HNSTransparent

stop-service ovs-vswitchd -force; disable-vmswitchextension "cloudbase open vswitch extension";
ovs-vsctl --no-wait del-br br-ex

ovs-vsctl --no-wait --may-exist add-br br-ex
ovs-vsctl --no-wait add-port br-ex HNSTransparent -- set interface HNSTransparent type=internal
ovs-vsctl --no-wait add-port br-ex $INTERFACE_ALIAS

enable-vmswitchextension "cloudbase open vswitch extension"; sleep 2; restart-service ovs-vswitchd

ovs-vsctl set Open_vSwitch . external_ids:k8s-api-server="$($KUBERNETES_API_SERVER):8080"
ovs-vsctl set Open_vSwitch . external_ids:ovn-remote="tcp:$($KUBERNETES_API_SERVER):6642" external_ids:ovn-nb="tcp:$($KUBERNETES_API_SERVER):6641" external_ids:ovn-encap-ip=$PUBLIC_IP external_ids:ovn-encap-type="geneve"

$GUID = (New-Guid).Guid
ovs-vsctl set Open_vSwitch . external_ids:system-id="$($GUID)"

# On some cloud-providers this is needed, otherwise RDP connection may bork
netsh interface ipv4 set subinterface "HNSTransparent" mtu=1430 store=persistent

#expand k8s PoC binaries and create service
Expand-Archive -Force -Path "$($K8S_ZIP)" -DestinationPath "$($OVS_PATH)"

cmd /c 'sc create ovn-k8s binPath= "\"c:\Program Files\Cloudbase Solutions\Open vSwitch\bin\servicewrapper.exe\" ovn-k8s \"c:\Program Files\Cloudbase Solutions\Open vSwitch\bin\k8s_ovn.exe\"" type= own start= auto error= ignore depend= ovsdb-server/ovn-controller displayname= "OVN Watcher" obj= LocalSystem'

windows-init.exe windows-init --node-name $HOSTNAME --minion-switch-subnet $SUBNET --cluster-ip-subnet $CLUSTER_IP_SUBNET
start-service ovn-k8s


