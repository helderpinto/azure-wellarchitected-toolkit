param(
    [Parameter(Mandatory = $false)]
    [string] $Cloud = "AzureCloud",

    [Parameter(Mandatory = $false)]
    [string] $TargetSubscriptionId,

    [Parameter(Mandatory = $false)]
    [string[]] $AllowedRegions,

    [Parameter(Mandatory = $false)]
    [switch] $Simulate
)

$ctx = Get-AzContext

if (-not($ctx))
{
    $ctx = Connect-AzAccount -Environment $Cloud
}

$allowedRegionsString = $null
foreach ($region in $AllowedRegions) {
    if ($null -ne $allowedRegionsString)
    {
        $allowedRegionsString += ","
    }
    $allowedRegionsString += "'$region'"
}
Write-Output "Allowed regions: $allowedRegionsString"

Write-Output "About to remove all the Network Watchers in not allowed regions [SIMULATE=$Simulate] from tenant $($ctx.Tenant.TenantId) ($Cloud) for subscription $TargetSubscriptionId..."
$continueInput = Read-Host "Continue (Y/N)?"

if ("Y", "y" -contains $continueInput) {

    if ([string]::IsNullOrEmpty($TargetSubscriptionId))
    {
        $subscriptions = Get-AzSubscription | ForEach-Object { "$($_.Id)"}
    }
    else
    {
        $subscriptions = $TargetSubscriptionId
    }    

    $queryText = @"
    resources
    | where type =~ 'microsoft.network/networkwatchers' and location !in ($allowedRegionsString)
    | order by id
"@
    $networkWatchers = Search-AzGraph -Query $queryText -Subscription $subscriptions -First 1000
    
    Write-Output "Found $($networkWatchers.Count) network watchers"

    $currentSubscription = $null

    foreach ($nw in $networkWatchers) {
        Write-Output "Removing $($nw.name) from $($nw.subscriptionId)/$($nw.resourceGroup)..."
        if (-not($Simulate))
        {
            if ($currentSubscription -ne $nw.subscriptionId)
            {
                Select-AzSubscription -SubscriptionId $nw.subscriptionId | Out-Null
                $currentSubscription = $nw.subscriptionId
            }
            Remove-AzNetworkWatcher -Name $nw.name -ResourceGroup $nw.resourceGroup
        }
    }
}