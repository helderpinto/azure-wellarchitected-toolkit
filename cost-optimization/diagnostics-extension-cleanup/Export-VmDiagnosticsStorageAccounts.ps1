param(
    [Parameter(Mandatory = $false)]
    [string] $Cloud = "AzureCloud"
)

$ctx = Get-AzContext

if (-not($ctx))
{
    $ctx = Connect-AzAccount -Environment $Cloud
}

$subscriptions = Get-AzSubscription | ForEach-Object { "$($_.Id)"}

$queryText = @"
resources 
| where type =~ 'microsoft.compute/virtualmachines/extensions' and tostring(properties.type) in ('LinuxDiagnostic', 'IaaSDiagnostics')
| extend storageAccountName = iif(isempty(tostring(properties.settings.StorageAccount)),tostring(properties.settings.storageAccount),tostring(properties.settings.StorageAccount))
| project id, storageAccountName
| join kind=inner (
	resources
	| where type =~ 'microsoft.storage/storageAccounts'
	| project storageAccountName = name, resourceGroup, subscriptionId
) on storageAccountName
| summarize count() by storageAccountName, resourceGroup, subscriptionId
"@

$diagStorageAccounts = Search-AzGraph -Query $queryText -Subscription $subscriptions

$csvExportPath = "diag-storageaccount-list-$Cloud.csv"
$diagStorageAccounts | Export-Csv -Path $csvExportPath -NoTypeInformation

Write-Output "Successfully exported diagnostics storage accounts details to $csvExportPath!"