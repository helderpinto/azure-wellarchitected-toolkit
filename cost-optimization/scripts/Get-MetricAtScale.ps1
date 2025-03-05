#Requires -Modules Az.Accounts
#Requires -Modules Az.Monitor
#Requires -Modules Az.ResourceGraph

<#
    Usage examples: 
    
    ./Get-MetricAtScale.ps1 -Namespace "microsoft.storage/storageaccounts" -MetricName "Transactions" -Interval "P1D" -Aggregation "Total" 
        -StartTime "2025-02-08T00:00:00Z" -EndTime "2025-03-05T00:00:00Z" 
        -Filter "ApiName ne 'GetBlobServiceProperties' and ApiName ne 'EntityGroupTransaction' and ApiName ne 'GetFileServiceProperties' and ApiName ne 'GetContainerProperties' and ApiName ne 'ListContainers'" 
        -ResourceIdARGQuery "resources | where type == 'microsoft.storage/storageaccounts' | project id,location | order by location,id"

    ./Get-MetricAtScale.ps1 -Namespace "Microsoft.Storage/storageAccounts/fileServices" -MetricName "FileCapacity,FileShareSnapshotCount" -Interval "PT1H" 
        -Aggregation "Average" -StartTime "2025-03-04T00:00:00Z" -EndTime "2025-03-05T00:00:00Z" 
        -ResourceIdARGQuery "resources | where type == 'microsoft.storage/storageaccounts' | project id=strcat(id,'/fileservices/default'),location | order by location,id"        
#>

param (
    [Parameter(Mandatory=$false)]
    [String] $AzureEnvironment = "AzureCloud",

    [Parameter(Mandatory=$false)]
    [ValidateSet('Interactive','SystemAssignedManagedIdentity','UserAssignedManagedIdentity')]
    [String] $SignInType = "Interactive",

    [Parameter(Mandatory=$false)]
    [String] $ClientId,

    [Parameter(Mandatory=$true)]
    [String] $Namespace,

    [Parameter(Mandatory=$true)]
    [String[]] $MetricName,

    [Parameter(Mandatory=$false)]
    [String] $Interval = "PT1H",

    [Parameter(Mandatory=$true)]
    [ValidateSet('Average','Minimum','Maximum','Total','Count')]
    [String] $Aggregation,

    [Parameter(Mandatory=$true)]
    [String] $StartTime,

    [Parameter(Mandatory=$true)]
    [String] $EndTime,

    [Parameter(Mandatory=$false)]
    [String] $Filter,

    [Parameter(Mandatory=$true)]
    [String] $ResourceIdARGQuery
)

$ErrorActionPreference = "Stop"

$ctx = Get-AzContext
if (-not($ctx) -or $ctx.Environment.Name -ne $AzureEnvironment)
{
    switch ($SignInType) {
        "Interactive" {
            $ctx = Connect-AzAccount -Environment $AzureEnvironment -UseDeviceAuthentication
        }
        "SystemAssignedManagedIdentity" {
            $ctx = Connect-AzAccount -Identity -Environment $AzureEnvironment
        }
        "UserAssignedManagedIdentity" {
            $ctx = Connect-AzAccount -Identity -AccountId $ClientId -Environment $AzureEnvironment
        }
        default {
            throw "Invalid SignInType $SignInType"
        }
    }
}

if (-not($ResourceIdARGQuery -like "*| order by location,id"))
{
    throw "ResourceIdARGQuery must end with `order by location,id` to support query response pagination and metrics requests batching"
}

function Split-ResourceIDsInBatches {
    param (
        [PSCustomObject[]] $Resources
    )

    $resourceBatches = @()    
    $resourceBatch = @()
    $idCounter = 0
    $totalIdCounter = 0
    $subscriptionId = $null
    $location = $null

    foreach ($resource in $Resources)
    {
        $resourceSubscriptionId = $resource.id.Split("/")[2]
        if ($subscriptionId -ne $resourceSubscriptionId -or $location -ne $resource.location -or $idCounter -eq 50)
        {
            $subscriptionId = $resourceSubscriptionId
            $location = $resource.location
            if ($resourceBatch.Count -gt 0)
            {
                $resourceBatches += ,$resourceBatch
                $idCounter = 0
            }
            $resourceBatch = @()
        }

        $resourceBatch += [PSCustomObject]@{
            ResourceId = $resource.id
            Location = $resource.location
        }
        $idCounter++
        $totalIdCounter++

        if ($totalIdCounter -eq $Resources.Count)
        {
            $resourceBatches += ,$resourceBatch
        }
    }

    return $resourceBatches    
}

$FinalResourceIdBatches = @()

$ARGPageSize = 50

$subscriptions = Get-AzSubscription | Where-Object { $_.State -eq "Enabled" } | ForEach-Object { "$($_.Id)"}

Write-Output "Collecting metrics across $($subscriptions.Count) subscriptions"

$argResources = @()
$resultsSoFar = 0

do
{
    if ($resultsSoFar -eq 0)
    {
        $argResults = Search-AzGraph -Query $ResourceIdARGQuery -Subscription $subscriptions.Id -First $ARGPageSize
    }
    else
    {
        $argResults = Search-AzGraph -Query $ResourceIdARGQuery -Subscription $subscriptions.Id -First $ARGPageSize -Skip $resultsSoFar
    }

    $resultsCount = $argResults.Data.Count
    $resultsSoFar += $resultsCount
    $argResources += $argResults.Data

} while ($resultsCount -eq $ARGPageSize)

Write-Output "Identified $($argResources.Count) resources"

$FinalResourceIdBatches = Split-ResourceIDsInBatches -Resources $argResources

Write-Output "Collecting metrics in $($FinalResourceIdBatches.Count) batches"

$metrics = @()

foreach ($batch in $FinalResourceIdBatches)
{
    $subscriptionId = $batch[0].ResourceId.Split("/")[2]
    $region = $batch[0].Location
    $endpoint = "https://$region.metrics.monitor.azure.com"
    $response = Get-AzMetricsBatch -Endpoint $endpoint -Name $MetricName -Namespace $Namespace -Interval $Interval -Aggregation $Aggregation `
        -EndTime $EndTime -StartTime $StartTime -ResourceId $batch.ResourceId -Filter $Filter -SubscriptionId $subscriptionId
    Write-Output "Got $($response.Count) batch results for subscription $subscriptionId in $region region."

    foreach ($resource in $response)
    {
        foreach ($resourceValue in $resource.Value)
        {
            foreach ($metric in $resourceValue.Timesery.Data)
            {
                $metrics += [PSCustomObject]@{
                    ResourceId  = $resource.ResourceId
                    Namespace   = $resource.Namespace
                    Region      = $resource.ResourceRegion
                    Metric      = $resourceValue.NameValue
                    Unit        = $resourceValue.Unit
                    MetricValue = $metric.$Aggregation
                    Aggregation = $Aggregation
                    Timestamp   = $metric.TimeStamp.ToUniversalTime().ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'fff'Z'")
                }
            }
        }
    }
}

Write-Output "Setting empty metrics for resources not found or with metrics filtered out..."

$notFoundMetricsCounter = 0
foreach ($argResource in $argResources)
{
    if (-not($argResource.id -in $metrics.ResourceId))
    {
        $notFoundMetricsCounter++
        $metrics += [PSCustomObject]@{
            ResourceId  = $argResource.id
            Namespace   = $Namespace
            Region      = $argResource.location
            Metric      = $MetricName -join "&"
            Unit        = "NotFound"
            MetricValue = 0
            Aggregation = $Aggregation
            Timestamp   = $StartTime
        }
    }
}

Write-Output "Added $notFoundMetricsCounter resources with empty metrics"

$file = "Metrics-$($MetricName -join "&")-$($Namespace.Replace("/","-"))-$($Aggregation)-$($Interval)-$([math]::Round(((Get-Date $EndTime) - (Get-Date $StartTime)).TotalHours))hrs-$((Get-Date $EndTime).ToString("yyyyMMddHHmmss")).csv"

$metrics | Export-Csv -Path $file

Write-Output "Metrics exported to $file"