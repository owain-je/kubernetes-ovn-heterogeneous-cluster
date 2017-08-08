
$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue"

Start-Transcript -path C:\windows-provision-start-script-log.txt -append

$containersFeature = Get-WindowsFeature Containers

if ( Test-Path c:\ovs\ready ) {
    #All set, do nothing

} elseif ( Test-Path C:\ovs\ ){

   cd C:\ovs\
   Start-BitsTransfer https://cloudbase.it/downloads/k8s_ovn_service_prerelease.zip

   #install ovn

   Start-BitsTransfer https://raw.githubusercontent.com/apprenda/kubernetes-ovn-heterogeneous-cluster/master/provisioning/gce/install_ovn.ps1
   .\install_ovn.ps1

   #install kubelet
   Start-BitsTransfer https://raw.githubusercontent.com/apprenda/kubernetes-ovn-heterogeneous-cluster/master/provisioning/gce/install_k8s.ps1
   .\install_k8s.ps1

   #set marker to prevent running this on reboot
   New-Item c:\ovs\ready -type file

} elseif ($containersFeature.Installed){
   cd \
   mkdir ovs
   cd ovs

   $K8S_MASTER_IP = Invoke-RestMethod -URI http://metadata.google.internal/computeMetadata/v1/instance/attributes/apiServer -Headers @{"Metadata-Flavor" = "Google"}
   setx -m CONTAINER_NETWORK "external"
   setx -m K8S_MASTER_IP "$K8S_MASTER_IP"

   #pull ovn and ovn-k8s bits
   Start-BitsTransfer https://cloudbase.it/downloads/openvswitch-hyperv-2.7.0-certified.msi

   Start-Sleep -s 10
   cmd /c 'msiexec /i openvswitch-hyperv-2.7.0-certified.msi /qn /L* ovs-msi-log.txt ADDLOCAL="OpenvSwitchCLI,OpenvSwitchDriver,OVNHost" '

   Restart-Computer -Force
} else {
    #Disable firewall
    netsh advfirewall set AllProfiles state off

    netsh netkvm setparam 0 *RscIPv4 0
    netsh netkvm restart 0

    Start-Sleep -s 10

    #Install Containers feature and restart
    Install-WindowsFeature -Name Containers

    #install docker
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Install-Module -Name DockerMsftProvider -Repository PSGallery -Force
    Install-Package -Name docker -ProviderName DockerMsftProvider -Force

    Restart-Computer -Force
}

Stop-Transcript