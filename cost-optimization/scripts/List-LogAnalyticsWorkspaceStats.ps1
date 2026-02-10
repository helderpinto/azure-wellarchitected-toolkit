param(
    [Parameter(Mandatory = $false)] 
    [String] $AzureEnvironment = "AzureCloud",

    [Parameter(Mandatory = $false)] 
    [String[]] $WorkspaceIds
)

$ErrorActionPreference = "Stop"

$ctx = Get-AzContext
if (-not($ctx)) {
    Connect-AzAccount -Environment $AzureEnvironment
    $ctx = Get-AzContext
}
else {
    if ($ctx.Environment.Name -ne $AzureEnvironment) {
        Disconnect-AzAccount -ContextName $ctx.Name
        Connect-AzAccount -Environment $AzureEnvironment
        $ctx = Get-AzContext
    }
}

$wsIds = foreach ($workspaceId in $WorkspaceIds)
{
    "'$workspaceId'"
}
if ($wsIds)
{
    $wsIds = $wsIds -join ","
    $whereWsIds = " and properties.customerId in ($wsIds)"
}

$ARGPageSize = 1000

$subscriptions = Get-AzSubscription | Where-Object { $_.State -eq "Enabled" } | ForEach-Object { "$($_.Id)"}

$argQuery = @"
resources 
| where type =~ 'microsoft.operationalinsights/workspaces'$whereWsIds
| project id, name, resourceGroup, subscriptionId, location, skuName = properties.sku.name, skuLevel = properties.sku.capacityReservationLevel, dailyCap = properties.workspaceCapping.dailyQuotaGb, retentionDays = properties.retentionInDays, workspaceId = properties.customerId
| order by id asc
"@

$workspaces = (Search-AzGraph -Query $argQuery -First $ARGPageSize -Subscription $subscriptions).data

Write-Output "Found $($workspaces.Count) workspaces."

$workspaceUsages = @()

$laQuery = "Usage | summarize IngestedGB=sum(Quantity/1024) by IsBillable, DataType"

foreach ($workspace in $workspaces) {
    $laQueryResults = $null
    $results = $null
    $laQueryResults = Invoke-AzOperationalInsightsQuery -WorkspaceId $workspace.workspaceId -Query $laQuery -Timespan (New-TimeSpan -Days 7) -ErrorAction Continue
    if ($laQueryResults)
    {
        $results = [System.Linq.Enumerable]::ToArray($laQueryResults.Results)
        Write-Output "$($workspace.name) ($($workspace.workspaceId)): $($results.Count) data type(s) ingested over last 7 days."    
    }
    else
    {
        Write-Output "$($workspace.name) ($($workspace.workspaceId)): could not validate ingested data types."
    }

    if ($workspace.subscriptionId -ne $ctx.Subscription.Id)
    {
        $ctx = Set-AzContext -SubscriptionId $workspace.subscriptionId | Out-Null
    }

    $tables = Get-AzOperationalInsightsTable -ResourceGroupName $workspace.resourceGroup -WorkspaceName $workspace.name

    foreach ($result in $results)
    {
        $table = $tables | Where-Object { $_.Name -eq $result.DataType }
        $workspaceUsage = New-Object PSObject -Property @{
            ResourceId = $workspace.id
            WorkspaceName = $workspace.name
            ResourceGroup = $workspace.resourceGroup
            SubscriptionId = $workspace.subscriptionId
            WorkspaceId = $workspace.workspaceId
            Region = $workspace.location
            SKUName = $workspace.skuName
            SKULevel = $workspace.skuLevel
            DailyCap = $workspace.dailyCap
            WorkspaceRetentionDays = $workspace.retentionDays
            TableName = $result.DataType
            TablePlan = $table.Plan
            TableRetentionDays = $table.RetentionInDays
            TableTotalRetentionDays = $table.TotalRetentionInDays
            IsBillable = $result.IsBillable
            IngestedGB7Days = $result.IngestedGB
        }
        $workspaceUsages += $workspaceUsage
    }
}

$workspaceUsages | Export-Csv -Path "la-workspace-usages.csv" -NoTypeInformation

Write-Output "Exported workspace usages to la-workspace-usages.csv."