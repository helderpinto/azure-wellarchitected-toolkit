param(
    [Parameter(Mandatory = $false)]
    [string] $Cloud = "AzureCloud"
)

$ctx = Get-AzContext

if (-not($ctx))
{
    $ctx = Connect-AzAccount -Environment $Cloud
}

$subscriptionsComplete = Get-AzSubscription | Where-Object { $_.State -eq "Enabled" }
$subscriptions = $subscriptionsComplete | ForEach-Object { "$($_.Id)"}

$ARGPageSize = 1000

$publicIPsConfigurations = @()

$resultsSoFar = 0

$queryText = @"
resources
| where type =~ 'microsoft.network/publicipaddresses'
| extend ipAddress = tostring(properties.ipAddress)
| extend ipConfigurationId = tolower(properties.ipConfiguration.id)
| where isnotempty(ipConfigurationId)
| extend associatedResourceType = tostring(split(ipConfigurationId, '/')[7])
| join kind=inner ( 
    resources
    | where type in ('microsoft.network/azurefirewalls', 'microsoft.network/networkinterfaces','microsoft.network/virtualnetworkgateways','microsoft.network/bastionhosts')
    | mvexpand ipConfiguration = properties.ipConfigurations
    | extend ipConfigurationId = tolower(ipConfiguration.id)
    | extend pipId = tolower(ipConfiguration.properties.publicIPAddress.id)
    | extend subnetId = tolower(ipConfiguration.properties.subnet.id)
    | project ipConfigurationId, associatedResourceId=tolower(id), associatedResourceName=name, pipId, subnetId
) on ipConfigurationId
| extend vnetId = strcat_array(array_slice(split(subnetId,'/'),0,8),'/')
| extend vnetName = tostring(split(vnetId,'/')[8])
| where isnotempty(vnetId)
| distinct id, ipAddress, name, resourceGroup, subscriptionId, associatedResourceType, associatedResourceId, associatedResourceName, vnetId, vnetName
"@

do
{
    if ($resultsSoFar -eq 0)
    {
        $argIpConfigs = Search-AzGraph -Query $queryText -First $ARGPageSize -Subscription $subscriptions
    }
    else
    {
        $argIpConfigs = Search-AzGraph -Query $queryText -First $ARGPageSize -Skip $resultsSoFar -Subscription $subscriptions 
    }
    $resultsCount = $argIpConfigs.Data.Count
    $resultsSoFar += $resultsCount
    $publicIPsConfigurations += $argIpConfigs.Data

} while ($resultsCount -eq $ARGPageSize)    

Write-Output "Found $($publicIPsConfigurations.Count) generic IP Configurations directly associated with Public IPs."

$resultsSoFar = 0

$queryText = @"
resources
| where type =~ 'microsoft.network/publicipaddresses'
| extend ipAddress = tostring(properties.ipAddress)
| extend ipConfigurationId = tolower(properties.ipConfiguration.id)
| where isnotempty(ipConfigurationId)
| extend associatedResourceType = tostring(split(ipConfigurationId, '/')[7])
| join kind=inner ( 
    resources
    | where type == 'microsoft.network/applicationgateways'
    | mvexpand ipConfiguration = properties.frontendIPConfigurations
    | extend ipConfigurationId = tolower(ipConfiguration.id)
    | extend pipId = tolower(ipConfiguration.properties.publicIPAddress.id)
    | mvexpand gwIpConfiguration = properties.gatewayIPConfigurations
    | extend subnetId = tolower(gwIpConfiguration.properties.subnet.id)
    | project ipConfigurationId, associatedResourceId=tolower(id), associatedResourceName=name, pipId, subnetId
) on ipConfigurationId
| extend vnetId = strcat_array(array_slice(split(subnetId,'/'),0,8),'/')
| extend vnetName = tostring(split(vnetId,'/')[8])
| distinct id, ipAddress, name, resourceGroup, subscriptionId, associatedResourceType, associatedResourceId, associatedResourceName, vnetId, vnetName
"@

do
{
    if ($resultsSoFar -eq 0)
    {
        $argIpConfigs = Search-AzGraph -Query $queryText -First $ARGPageSize -Subscription $subscriptions
    }
    else
    {
        $argIpConfigs = Search-AzGraph -Query $queryText -First $ARGPageSize -Skip $resultsSoFar -Subscription $subscriptions 
    }
    $resultsCount = $argIpConfigs.Data.Count
    $resultsSoFar += $resultsCount
    $publicIPsConfigurations += $argIpConfigs.Data

} while ($resultsCount -eq $ARGPageSize)    

Write-Output "[UPDATED with AppGWs] Found $($publicIPsConfigurations.Count) IP Configurations directly associated with Public IPs."

$resultsSoFar = 0

$queryText = @"
resources
| where type =~ 'microsoft.network/publicipaddresses'
| extend ipAddress = tostring(properties.ipAddress)
| extend ipConfigurationId = tolower(properties.ipConfiguration.id)
| where isnotempty(ipConfigurationId)
| extend associatedResourceType = tostring(split(ipConfigurationId, '/')[7])
| join kind=inner ( 
    resources
    | where type =~ 'microsoft.network/loadbalancers'
    | mvexpand backendPool = properties.backendAddressPools
    | mvexpand backendIPConfiguration = backendPool.properties.backendIPConfigurations
    | mvexpand ipConfiguration = properties.frontendIPConfigurations
    | extend ipConfigurationId = tolower(ipConfiguration.id)
    | extend pipId = tolower(ipConfiguration.properties.publicIPAddress.id)
    | where isnotempty(pipId)
    | extend nicIpConfigId = tolower(backendIPConfiguration.id)
    | project ipConfigurationId, associatedResourceId=tolower(id), associatedResourceName=name, pipId, nicIpConfigId
    | where isnotempty(nicIpConfigId)
    | extend nicIpConfigId = iif(nicIpConfigId contains "microsoft.compute/virtualmachinescalesets", strcat_array(array_slice(split(nicIpConfigId,'/'),0,8),'/'), nicIpConfigId)
    | project ipConfigurationId, associatedResourceId, associatedResourceName, pipId, nicIpConfigId
) on ipConfigurationId
| distinct id, ipAddress, name, resourceGroup, subscriptionId, associatedResourceType, associatedResourceId, associatedResourceName, nicIpConfigId
"@

do
{
    if ($resultsSoFar -eq 0)
    {
        $argIpConfigs = Search-AzGraph -Query $queryText -First $ARGPageSize -Subscription $subscriptions
    }
    else
    {
        $argIpConfigs = Search-AzGraph -Query $queryText -First $ARGPageSize -Skip $resultsSoFar -Subscription $subscriptions 
    }
    $resultsCount = $argIpConfigs.Data.Count
    $resultsSoFar += $resultsCount

    foreach ($ipConfig in $argIpConfigs.Data)
    {
        $innerQueryText = @"
        resources
        | where type =~ 'microsoft.network/networkinterfaces'
        | mvexpand ipConfiguration = properties.ipConfigurations
        | extend nicIpConfigId = tolower(ipConfiguration.id)
        | where nicIpConfigId =~ '$($ipConfig.nicIpConfigId)'
        | extend subnetId = tolower(ipConfiguration.properties.subnet.id)
        | project nicIpConfigId, subnetId
        | union ( 
            resources
            | where type =~ 'microsoft.compute/virtualmachinescalesets'
            | project nicIpConfigId=tolower(id), subnetId = tolower(properties.virtualMachineProfile.networkProfile.networkInterfaceConfigurations[0].properties.ipConfigurations[0].properties.subnet.id)
            | where nicIpConfigId =~ '$($ipConfig.nicIpConfigId)'
        )
        | extend id = '$($ipConfig.id)'
        | extend ipAddress = '$($ipConfig.ipAddress)'
        | extend name = '$($ipConfig.name)'
        | extend resourceGroup = '$($ipConfig.resourceGroup)'
        | extend subscriptionId = '$($ipConfig.subscriptionId)'
        | extend associatedResourceType = '$($ipConfig.associatedResourceType)'
        | extend associatedResourceId = '$($ipConfig.associatedResourceId)'
        | extend associatedResourceName = '$($ipConfig.associatedResourceName)'
        | extend vnetId = strcat_array(array_slice(split(subnetId,'/'),0,8),'/')
        | extend vnetName = tostring(split(vnetId,'/')[8])
        | distinct id, ipAddress, name, resourceGroup, subscriptionId, associatedResourceType, associatedResourceId, associatedResourceName, vnetId, vnetName
"@            

        $argIpConfigsInner = Search-AzGraph -Query $innerQueryText -First $ARGPageSize -Subscription $subscriptions
        $publicIPsConfigurations += $argIpConfigsInner.Data
    }
} while ($resultsCount -eq $ARGPageSize)    

Write-Output "[UPDATED with LBs] Found $($publicIPsConfigurations.Count) IP Configurations associated with Public IPs."

$pipAssociations = @()

foreach ($pipIpConfig in $publicIPsConfigurations)
{
    if (-not($pipAssociations | Where-Object { $_.PublicIPId -eq $pipIpConfig.id -and $_.VNetId -eq $pipIpConfig.vNetId })) {
        $logentry = New-Object PSObject -Property @{
            PublicIPId = $pipIpConfig.id
            IPAddress = $pipIpConfig.ipAddress
            PublicIPName = $pipIpConfig.name
            ResourceGroup = $pipIpConfig.resourceGroup
            SubscriptionName = ($subscriptionsComplete | Where-Object { $_.Id -eq $pipIpConfig.subscriptionId }).Name
            BackendType = $pipIpConfig.associatedResourceType
            BackendId = $pipIpConfig.associatedResourceId
            BackendName = $pipIpConfig.associatedResourceName
            VNetId = $pipIpConfig.vNetId
            VNetName = $pipIpConfig.vnetName
        }
        $pipAssociations += $logentry            
    }
}

Write-Output "[Removed duplicates] Found $($pipAssociations.Count) IP Configurations overall associated with Public IPs."

foreach ($pipAssociation in $pipAssociations)
{
    if ([string]::IsNullOrEmpty($pipAssociation.VNetId))
    {
        $associationWithVNet = ($pipAssociations | Where-Object { $_.BackendId -eq $pipAssociation.BackendId -and -not([string]::IsNullOrEmpty($_.VNetId)) })[0]
        $pipAssociation.VNetId = $associationWithVNet.VNetId
        $pipAssociation.VNetName = $associationWithVNet.VNetName
    }
}

$csvExportPath = "publicips-associations-list-$Cloud.csv"
$pipAssociations | Export-Csv -Path $csvExportPath -NoTypeInformation

Write-Output "Successfully exported Public IP associations details to $csvExportPath!"
