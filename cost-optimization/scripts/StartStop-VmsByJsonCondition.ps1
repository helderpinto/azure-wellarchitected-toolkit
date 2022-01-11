<#
.SYNOPSIS

Shuts down or starts VMs according to a tags condition.

.PARAMETER Simulate
Whether the outcome will be simulated or not

.PARAMETER DesiredState
Desired state for the VM: StoppedDeallocated or Running

.PARAMETER ConditionDefinition
A JSON object enumerating the tags name/values pairs and/or resource group names that must be met by the VM to be included in the scope. Example:
{
    "tagsCondition": [
        {
            "name": "tagName1",
            "value": "tagValue1"
        },
        {
            "name": "tagName2",
            "value": "tagValue2"
        }
    ],
    "resourceGroupsCondition": [
        "resourceGroupName1",
        "resourceGroupName2"
    ],
    "resourceGraphCondition": "properties.storageProfile.osDisk.osType == 'Windows'"
}

.PARAMETER TargetSubscription
A target subscription ID.

Author: Helder Pinto

#>

param(
    [parameter(Mandatory=$false)]
    [bool]$Simulate = $true,

    [parameter(Mandatory=$false)]
    [ValidateSet("Running","StoppedDeallocated")]
    [string]$DesiredState = "StoppedDeallocated",

    [parameter(Mandatory=$true)]
    [string]$ConditionDefinition,

    [parameter(Mandatory=$false)]
    [string]$TargetSubscription
)

function BuildARGWhereClause {
    param (
        [parameter(Mandatory=$true)]
        [object]$ConditionJson
    )

    $whereClause = ""
    $clauseTagsSegmentTemplate = " and tags.['{0}'] =~ '{1}'"
    $clauseResourceGroupSegmentTemplate = " and resourceGroup in ('{0}')"
    $clauseResourceGraphSegmentTemplate = " and {0}"
    
    foreach ($tag in $ConditionJson.tagsCondition) {
        $clauseSegment = $clauseTagsSegmentTemplate -f $tag.name, $tag.value
        $whereClause += $clauseSegment
    }

    if ($ConditionJson.resourceGroupsCondition.Count -gt 0)
    {
        $clauseSegment = $clauseResourceGroupSegmentTemplate -f ($ConditionJson.resourceGroupsCondition -join "','")
        $whereClause += $clauseSegment
    }

    if (-not([string]::IsNullOrEmpty($ConditionJson.resourceGraphCondition)))
    {
        $clauseSegment = $clauseResourceGraphSegmentTemplate -f $ConditionJson.resourceGraphCondition
        $whereClause += $clauseSegment
    }

    return $whereClause
}

function AssertResourceManagerVirtualMachinePowerState
{
    param(
        [object]$VirtualMachine,
        [string]$DesiredState,
        [bool]$Simulate
    )

    # Get VM with current status
    $resourceManagerVM = Get-AzVM -ResourceGroupName $VirtualMachine.resourceGroup -Name $VirtualMachine.name -Status
    $currentStatus = $resourceManagerVM.Statuses | Where-Object { $_.Code -like "PowerState*" }
    $currentStatus = $currentStatus.Code -replace "PowerState/",""

    # If should be running and isn't, start VM
    if($DesiredState -eq "Running" -and $currentStatus -notmatch "running")
    {
        if($Simulate)
        {
            Write-Output "[$($VirtualMachine.name)]: SIMULATION -- Would have started VM. (No action taken)"
        }
        else
        {
            Write-Output "[$($VirtualMachine.name)]: Starting VM"
            $resourceManagerVM | Start-AzVM -NoWait
        }
    }
        
    # If should be stopped and isn't, stop VM
    elseif($DesiredState -eq "StoppedDeallocated" -and $currentStatus -ne "deallocated")
    {
        if($Simulate)
        {
            Write-Output "[$($VirtualMachine.name)]: SIMULATION -- Would have stopped VM. (No action taken)"
        }
        else
        {
            Write-Output "[$($VirtualMachine.name)]: Stopping VM"
            $resourceManagerVM | Stop-AzVM -Force
        }
    }

    # Otherwise, current power state is correct
    else
    {
        Write-Output "[$($VirtualMachine.name)]: Current power state [$currentStatus] is correct."
    }
}

$ErrorActionPreference = "Stop"

$currentTime = (Get-Date).ToUniversalTime()
Write-Output "Runbook started. Version: $VERSION"
if($Simulate)
{
    Write-Output "*** Running in SIMULATE mode. No power actions will be taken. ***"
}
else
{
    Write-Output "*** Running in LIVE mode. Desired state will be enforced. ***"
}
Write-Output "Current UTC/GMT time [$($currentTime.ToString("dddd, yyyy MMM dd HH:mm:ss"))]"

Write-Output "Asserting $DesiredState state for VMs with the following constraints: $ConditionDefinition"

$cloudEnvironment = Get-AutomationVariable -Name "StartStopVMs_CloudEnvironment" -ErrorAction SilentlyContinue # AzureCloud|AzureChinaCloud
if ([string]::IsNullOrEmpty($cloudEnvironment))
{
    $cloudEnvironment = "AzureCloud"
}
$authenticationOption = Get-AutomationVariable -Name "StartStopVMs_AuthenticationOption" -ErrorAction SilentlyContinue # RunAsAccount|ManagedIdentity
if ([string]::IsNullOrEmpty($authenticationOption))
{
    $authenticationOption = "ManagedIdentity"
}

Write-Output "Logging in to Azure with $authenticationOption..."

switch ($authenticationOption) {
    "RunAsAccount" { 
        $ArmConn = Get-AutomationConnection -Name AzureRunAsConnection
        Connect-AzAccount -ServicePrincipal -EnvironmentName $cloudEnvironment -Tenant $ArmConn.TenantID -ApplicationId $ArmConn.ApplicationID -CertificateThumbprint $ArmConn.CertificateThumbprint
        break
    }
    "ManagedIdentity" { 
        Connect-AzAccount -Identity
        break
    }
    Default {
        $ArmConn = Get-AutomationConnection -Name AzureRunAsConnection
        Connect-AzAccount -ServicePrincipal -EnvironmentName $cloudEnvironment -Tenant $ArmConn.TenantID -ApplicationId $ArmConn.ApplicationID -CertificateThumbprint $ArmConn.CertificateThumbprint
        break
    }
}

Write-Output "Getting subscriptions target $TargetSubscription"
if (-not([string]::IsNullOrEmpty($TargetSubscription)))
{
    $subscriptions = $TargetSubscription
}
else
{
    $subscriptions = Get-AzSubscription | ForEach-Object { "$($_.Id)"}
}

Write-Output "Using the following target subscriptions: $subscriptions"

$conditionJson = $ConditionDefinition | ConvertFrom-Json
$argWhereClause = BuildARGWhereClause -ConditionJson $conditionJson

$argQuery = @"
resources
| where type =~ 'Microsoft.Compute/virtualMachines'$argWhereClause
| order by id
"@

Write-Output "Querying for VMs with the following query: $argQuery"

if (-not([string]::IsNullOrEmpty($argWhereClause)))
{
    $vmScopeResults = Search-AzGraph -Query $argQuery -Subscription $subscriptions

    Write-Output "Found $($vmScopeResults.Data.Count) VMs meeting the query criteria."

    foreach ($vm in $vmScopeResults.Data) {

        $ctx = Get-AzContext
        if ($ctx.Subscription.Id -ne $vm.subscriptionId)
        {
            Select-AzSubscription -SubscriptionId $vm.subscriptionId | Out-Null
        }

        AssertResourceManagerVirtualMachinePowerState -VirtualMachine $vm -DesiredState $DesiredState -Simulate $Simulate        
    }
}
else
{
    Write-Output "The ARG where clause is too broad. No actions will be taken."
}

Write-Output "Runbook finished (Duration: $(("{0:hh\:mm\:ss}" -f ((Get-Date).ToUniversalTime() - $currentTime))))"
