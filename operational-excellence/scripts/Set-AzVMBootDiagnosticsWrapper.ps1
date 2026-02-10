<#
.SYNOPSIS
    Configures Boot Diagnostics for Azure Virtual Machines in bulk.

.DESCRIPTION
    This script uses Azure Resource Graph to identify Virtual Machines matching specific criteria and configures their Boot Diagnostics settings.
    It supports enabling Managed Boot Diagnostics, enabling Boot Diagnostics with a specific Storage Account, or disabling Boot Diagnostics.
    Only processes VMs that require changes to their current configuration.

.PARAMETER TargetSubscriptionId
    Optional list of Subscription IDs to process. If not provided, processes all enabled subscriptions in the current context.

.PARAMETER Action
    The action to perform:
    - Disable: Disables Boot Diagnostics.
    - EnableManaged: Switches to Managed Boot Diagnostics (recommended).
    - EnableStorageAccount: Enables Boot Diagnostics pointing to a specific Storage Account (legacy).

.PARAMETER ARGFilter
    Optional Azure Resource Graph KQL filter to limit the scope (e.g., "resourceGroup == 'myRG'").

.PARAMETER StorageAccountId
    The Resource ID of the Storage Account to use. Required if Action is 'EnableStorageAccount'.

.PARAMETER Cloud
    Azure Cloud environment (default: AzureCloud).

.PARAMETER Simulate
    Runs the script in dry mode.

.EXAMPLE
    .\Set-AzVMBootDiagnosticsWrapper.ps1 -Action EnableManaged -ARGFilter "resourceGroup == 'production-rg'" -Simulate

    Checks for VMs in 'production-rg' that do not have Managed Boot Diagnostics and simulates enabling it.

.EXAMPLE
    .\Set-AzVMBootDiagnosticsWrapper.ps1 -Action Disable -SubscriptionId "sub-guid-123"

    Disables Boot Diagnostics for all VMs in subscription 'sub-guid-123'.

.NOTES
    Author: Hélder Pinto
    Date: 2026
#>
param(
    [Parameter(Mandatory = $false)]
    [string] $Cloud = "AzureCloud",

    [Parameter(Mandatory = $false)]
    [string] $TargetSubscriptionId,

    [parameter(Mandatory = $true)]
    [ValidateSet("Disable", "EnableManaged", "EnableStorageAccount")]
    [string] $Action,

    [Parameter(Mandatory = $false)]
    [string] $ARGFilter,

    [Parameter(Mandatory = $false)]
    [string] $StorageAccountId,

    [Parameter(Mandatory = $false)]
    [switch] $Simulate
)

if ($Action -eq "EnableStorageAccount" -and [string]::IsNullOrEmpty($StorageAccountId)) {
    throw "StorageAccountId must be provided when Action is 'EnableStorageAccount'."
}

$ctx = Get-AzContext
if (-not($ctx)) {
    Connect-AzAccount -Environment $Cloud
    $ctx = Get-AzContext
}
else {
    if ($ctx.Environment.Name -ne $Cloud) {
        Disconnect-AzAccount -ContextName $ctx.Name
        Connect-AzAccount -Environment $Cloud
        $ctx = Get-AzContext
    }
}

if ([string]::IsNullOrEmpty($TargetSubscriptionId)) {
    $subscriptions = Get-AzSubscription | Where-Object { $_.State -eq "Enabled" } | ForEach-Object { "$($_.Id)" }
}
else {
    $subscriptions = $TargetSubscriptionId
}

$ARGPageSize = 100

$argWhere = ""
if (-not([string]::IsNullOrEmpty($ARGFilter))) {
    $argWhere = " and $ARGFilter"
}

$argQuery = @"
resources 
| where type =~ 'microsoft.compute/virtualmachines'$argWhere
| extend powerState = tostring(properties.extended.instanceView.powerState.code)
| extend diagAccount = tostring(split(parse_url(tostring(properties.diagnosticsProfile.bootDiagnostics.storageUri)).Host,'.')[0])
| extend bootDiagnosticsEnabled = tobool(coalesce(properties.diagnosticsProfile.bootDiagnostics.enabled, "false"))
| project id=tolower(id), name=tolower(name), resourceGroup=tolower(resourceGroup), subscriptionId, powerState, bootDiagnosticsEnabled, diagAccount
| order by id asc
"@

$argResources = @()
$resultsSoFar = 0

do
{
    if ($resultsSoFar -eq 0)
    {
        $argResults = Search-AzGraph -Query $argQuery -Subscription $subscriptions -First $ARGPageSize
    }
    else
    {
        $argResults = Search-AzGraph -Query $argQuery -Subscription $subscriptions -First $ARGPageSize -Skip $resultsSoFar
    }

    $resultsCount = $argResults.Data.Count
    $resultsSoFar += $resultsCount
    $argResources += $argResults.Data

} while ($resultsCount -eq $ARGPageSize)

switch ($Action) {
    "EnableManaged" {
        $vmsToEnable = $argResources | Where-Object { -not($_.bootDiagnosticsEnabled) -or -not([string]::IsNullOrEmpty( $_.diagAccount)) }
        Write-Output "Enabling managed boot diagnostics in $($vmsToEnable.Count) machines"
        foreach ($vm in $vmsToEnable)
        {
            Write-Output "Processing $($vm.name)..."
            if ($ctx.Subscription.Id -ne $vm.subscriptionId) {
                $ctx = Select-AzSubscription -SubscriptionId $vm.subscriptionId
            }

            if (-not($Simulate))
            {
                $vmObject = Get-AzVm -ResourceGroupName $vm.resourceGroup -Name $vm.name
                $vmObject.DiagnosticsProfile.BootDiagnostics.StorageUri = $null
                Set-AzVMBootDiagnostic -VM $vmObject -Enable | Out-Null
                Update-AzVM -VM $vmObject -ResourceGroupName $vm.resourceGroup | Out-Null
            }
        }
        break
    }
    "EnableStorageAccount" {
        $saParts = $StorageAccountId.Split('/')
        $vmsToEnable = $argResources | Where-Object { -not($_.bootDiagnosticsEnabled) -or $_.diagAccount -ne $saParts[-1] }
        Write-Output "Enabling boot diagnostics to $($saParts[-1]) Storage Account in $($vmsToEnable.Count) machines"
        foreach ($vm in $vmsToEnable)
        {
            Write-Output "Processing $($vm.name)..."
            if ($ctx.Subscription.Id -ne $vm.subscriptionId) {
                $ctx = Select-AzSubscription -SubscriptionId $vm.subscriptionId
            }

            if (-not($Simulate))
            {
                $vmObject = Get-AzVm -ResourceGroupName $vm.resourceGroup -Name $vm.name
                Set-AzVMBootDiagnostic -VM $vmObject -Enable -ResourceGroupName $saParts[4] -StorageAccountName $saParts[-1] | Out-Null
                Update-AzVM -VM $vmObject -ResourceGroupName $vm.resourceGroup | Out-Null
            }
        }
        break
    }
    "Disable" {
        $vmsToDisable = $argResources | Where-Object { $_.bootDiagnosticsEnabled }
        Write-Output "Disabling boot diagnostics in $($vmsToDisable.Count) machines"
        foreach ($vm in $vmsToDisable)
        {
            Write-Output "Processing $($vm.name)..."
            if ($ctx.Subscription.Id -ne $vm.subscriptionId) {
                $ctx = Select-AzSubscription -SubscriptionId $vm.subscriptionId
            }

            if (-not($Simulate))
            {
                $vmObject = Get-AzVm -ResourceGroupName $vm.resourceGroup -Name $vm.name
                Set-AzVMBootDiagnostic -VM $vmObject -Disable | Out-Null
                Update-AzVM -VM $vmObject -ResourceGroupName $vm.resourceGroup | Out-Null
            }
        }
        break
    }
    Default {
        throw "Invalid Action specified."
    }
}

