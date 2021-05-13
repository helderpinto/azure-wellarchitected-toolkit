param (
    [Parameter(Mandatory = $true)]
    [string] $PolicyAssignmentId,

    [Parameter(Mandatory = $false)]
    [string] $ManagementGroupId,

    [Parameter(Mandatory = $false)]
    [string] $SubscriptionId
)

$ErrorActionPreference = "Stop"

Connect-AzAccount -Identity

$assignment = Get-AzPolicyAssignment -Id $PolicyAssignmentId
if (-not($assignment))
{
    throw "Assignment $PolicyAssignmentId not found"
}

if (-not($ManagementGroupId -or $SubscriptionId))
{
    throw "No management group nor subscription id provided"
}

if ($ManagementGroupId)
{
    Write-Output "Remediating $($assignment.Properties.DisplayName) policy assignment in $ManagementGroupId Management Group..."
    $complianceState = Get-AzPolicyState -ManagementGroupName $ManagementGroupId `
        -Filter "PolicyAssignmentName eq '$($assignment.Name)' and ComplianceState eq 'NonCompliant'" `
        -Apply "groupby((PolicyDefinitionReferenceId), aggregate(`$count as NumStates))" -OrderBy "NumStates desc"
}
else
{
    Select-AzSubscription -SubscriptionId $SubscriptionId
    Write-Output "Remediating $($assignment.Properties.DisplayName) policy assignment in $SubscriptionId Subscription..."
    $complianceState = Get-AzPolicyState -Filter "PolicyAssignmentName eq '$($assignment.Name)' and ComplianceState eq 'NonCompliant'" `
        -Apply "groupby((PolicyDefinitionReferenceId), aggregate(`$count as NumStates))" -OrderBy "NumStates desc"
}
Write-Output "Found $($complianceState.Count) non-compliant policies"

foreach ($nonCompliant in $complianceState)
{
    Write-Output "Remediating $($nonCompliant.AdditionalProperties['NumStates']) resources for PolicyDefinitionReferenceId $($nonCompliant.PolicyDefinitionReferenceId)..."
    if ($ManagementGroupId)
    {
        Start-AzPolicyRemediation -Name (New-Guid).Guid -ManagementGroupName $ManagementGroupId `
            -PolicyAssignmentId $PolicyAssignmentId -PolicyDefinitionReferenceId $nonCompliant.PolicyDefinitionReferenceId | Out-Null
    }
    else
    {
        Start-AzPolicyRemediation -Name (New-Guid).Guid -PolicyAssignmentId $PolicyAssignmentId `
            -PolicyDefinitionReferenceId $nonCompliant.PolicyDefinitionReferenceId | Out-Null
    }
}
Write-Output "DONE"