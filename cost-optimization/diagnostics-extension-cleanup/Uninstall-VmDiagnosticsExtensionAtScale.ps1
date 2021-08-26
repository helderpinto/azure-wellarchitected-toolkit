param(
    [Parameter(Mandatory = $false)]
    [string] $Cloud = "AzureCloud",

    [Parameter(Mandatory = $false)]
    [string] $TargetSubscriptionId,

    [Parameter(Mandatory = $false)]
    [string] $TargetResourceGroup,

    [Parameter(Mandatory = $false)]
    [switch] $RemoveLocks,

    [Parameter(Mandatory = $false)]
    [switch] $StartVMs,

    [Parameter(Mandatory = $false)]
    [switch] $Simulate
)

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

Write-Output "About to remove all the Diagnostics Extensions [SIMULATE=$Simulate] from tenant $($ctx.Tenant.TenantId) ($Cloud) for subscription $TargetSubscriptionId and resource group $TargetResourceGroup..."
$continueInput = Read-Host "Continue (Y/N)?"

if ("Y", "y" -contains $continueInput) {

    $ARGPageSize = 1000
    $extensions = @()
    $extensionsArg = @()
    
    if ([string]::IsNullOrEmpty($TargetSubscriptionId))
    {
        $subscriptions = Get-AzSubscription | ForEach-Object { "$($_.Id)"}
    }
    else
    {
        $subscriptions = $TargetSubscriptionId
    }
    
    $resultsSoFar = 0
    
    $queryText = @"
    resources 
    | where type =~ 'microsoft.compute/virtualmachines/extensions' and tostring(properties.type) in ('LinuxDiagnostic', 'IaaSDiagnostics')
    | project id, name
    | extend vmId = substring(id, 0, indexof(id, '/extensions/'))
    | join kind=inner (
        resources 
        | where type =~ 'microsoft.compute/virtualmachines'
        | project vmId = id, vmName = name, resourceGroup, subscriptionId, powerState = tostring(properties.extended.instanceView.powerState.code)
    ) on vmId
    | project-away vmId, vmId1
    | order by id asc
"@
    
    do
    {
        if ($resultsSoFar -eq 0)
        {
            $armExtensions = (Search-AzGraph -Query $queryText -First $ARGPageSize -Subscription $subscriptions).data
        }
        else
        {
            $armExtensions = (Search-AzGraph -Query $queryText -First $ARGPageSize -Skip $resultsSoFar -Subscription $subscriptions).data
        }
        $resultsCount = $armExtensions.Count
        $resultsSoFar += $resultsCount
        $extensionsArg += $armExtensions
    
    } while ($resultsCount -eq $ARGPageSize)    
    
    Write-Output "Found $($extensionsArg.Count) extensions overall."
    
    foreach ($extension in $extensionsArg)
    {
        if ([string]::IsNullOrEmpty($TargetResourceGroup) -or $extension.resourceGroup -eq $TargetResourceGroup)
        {
            Write-Output "Disabling extension in $($extension.subscriptionId)/$($extension.resourceGroup)/$($extension.vmName)..."

            if ($ctx.Subscription.Id -ne $extension.subscriptionId)
            {
                $ctx = Select-AzSubscription -SubscriptionId $extension.subscriptionId
            }
    
            $hasLocks = $false
            $wasStopped = $false
            $isStarted = $true
            $extensionRemoved = $false
    
            $vmDetails = Get-AzVm -ResourceGroupName $extension.resourceGroup -Name $extension.vmName -Status
            if (($vmDetails.Statuses | Where-Object { $_.Code -like "PowerState*" }).Code -notlike "*running" )
            {
                $wasStopped = $true
                $isStarted = $false
            }    

            $locks = Get-AzResourceLock -ResourceName $extension.vmName -ResourceType 'Microsoft.Compute/virtualMachines' -ResourceGroupName $extension.resourceGroup -AtScope
            if ($locks.Count -gt 0)
            {
                $hasLocks = $true
            }

            if ($wasStopped -and $StartVMs -and (-not($hasLocks) -or $RemoveLocks))
            {
                Write-Output "Starting VM..."
                if (-not($Simulate))
                {
                    Start-AzVM -ResourceGroupName $extension.resourceGroup -Name $extension.vmName | Out-Null
                    Write-Output "VM started. Waiting a bit more to increase chances of success..."
                    Start-Sleep -Seconds 60 # give enough time for the VM Agent to successfully process requests
                }                
                $isStarted = $true
            }

            if ($isStarted)
            {
                if (-not($hasLocks) -or $RemoveLocks)
                {
                    if ($RemoveLocks)
                    {
                        foreach ($lock in $locks)
                        {
                            Write-Output "Removing lock $($lock.Name)..."
                            if (-not($Simulate))
                            {
                                Remove-AzResourceLock -LockId $lock.LockId -Force | Out-Null
                            }
                        }    
                    }

                    Write-Output "Removing extension $($extension.name)..."
                    if (-not($Simulate))
                    {
                        if ($wasStopped)
                        {
                            Remove-AzVMDiagnosticsExtension -ResourceGroupName $extension.resourceGroup -VMName $extension.vmName -Name $extension.name | Out-Null                            
                        }
                        else
                        {
                            Remove-AzVMDiagnosticsExtension -ResourceGroupName $extension.resourceGroup -VMName $extension.vmName -Name $extension.name -NoWait | Out-Null                            
                        }
                        $extensionRemoved = $true
                    }

                    if ($RemoveLocks)
                    {
                        foreach ($lock in $locks)
                        {
                            Write-Output "Re-adding lock $($lock.Name)..."

                            if ([string]::IsNullOrEmpty($lock.Properties.notes))
                            {
                                if (-not($Simulate))
                                {
                                    New-AzResourceLock -LockLevel $lock.Properties.level -LockId $lock.LockId -Force | Out-Null
                                }
                                
                            }
                            else
                            {
                                if (-not($Simulate))
                                {
                                    New-AzResourceLock -LockLevel $lock.Properties.level -LockNotes $lock.Properties.notes -LockId $lock.LockId -Force | Out-Null
                                }                                
                            }
                        }    
                    }
                }
                else
                {
                    Write-Output "Skipping as locks were not removed."
                }
            }
            else
            {
                Write-Output "Skipping as VM is not started and/or locks were not removed."
            }

            if ($wasStopped -and $StartVMs -and $isStarted)
            {
                Write-Output "De-allocating VM..."
                if (-not($Simulate))
                {
                    Stop-AzVM -ResourceGroupName $extension.resourceGroup -Name $extension.vmName -Force | Out-Null
                }                
            }

            $logentry = New-Object PSObject -Property @{
                VMName = $extension.vmName
                ExtensionName = $extension.name
                ResourceGroup = $extension.resourceGroup
                SubscriptionId = $extension.subscriptionId
                HadLocks = $hasLocks
                WasStopped = $wasStopped
                ExtensionRemoved = $extensionRemoved
            }
            $extensions += $logentry    
        }
    }

    $datetime = Get-Date
    $fileDate = $datetime.ToString("yyyyMMddHHmmss")
    $csvExportPath = "diag-removedextensions-list-$Cloud-$fileDate.csv"
    $extensions | Export-Csv -Path $csvExportPath -NoTypeInformation
    
    Write-Output "Successfully exported diagnostics removal details to $csvExportPath!"

    Write-Output "DONE!"
}
