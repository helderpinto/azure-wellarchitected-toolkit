param(
    [Parameter(Mandatory = $true)]
    [string] $TenantId,

    [Parameter(Mandatory = $false)]
    [string] $CloudEnvironment = "AzureCloud"
)

<#

This script requires the following modules:
- AzureADPreview
- MSOnline
- Az

Use Install-Module <module name> to install them if needed

NOTE: this script is interactive, as it requires a user to login to the 3 different services (Azure AD, MS Online, and Azure RM)

#>

$ErrorActionPreference = "Stop"

Write-Output "Connecting to Azure AD..."

try
{
    $tenantDetails = Get-AzureADTenantDetail
    if ($tenantDetails.ObjectId -ne $TenantId)
    {
        throw "Current tenant ID is different from the one defined as parameter"
    }
}
catch
{
    Connect-AzureAD -TenantId $TenantId -AzureEnvironmentName $CloudEnvironment        
}

Write-Output "Getting all users..."

# Getting all users from Graph API (Azure AD)
$users = Get-AzureADUser -All $true

Write-Output "Found $($users.Count) Azure AD users."

Write-Output "Connecting to MSOnline service..."

try
{
    $companyDetails = Get-MsolCompanyInformation
    if ($companyDetails.ObjectId.Guid -ne $TenantId)
    {
        throw "Current tenant ID is different from the one defined as parameter"
    }
}
catch
{
    Connect-MsolService -AzureEnvironment $CloudEnvironment
}

Write-Output "Getting all users..."

# Getting all users from Graph API (MSOL - MS Online)
$msolUsers = Get-MsolUser -All

Write-Output "Found $($msolUsers.Count) MS Online users."

Write-Output "Connecting to Azure Resource Manager..."

try
{
    $azContext = Get-AzContext
    if ($azContext.Tenant.Id -ne $TenantId)
    {
        throw "Current tenant ID is different from the one defined as parameter"
    }
}
catch
{
    Connect-AzAccount -Tenant $TenantId -Environment $CloudEnvironment
}

Write-Output "Getting all subscriptions..."

$subscriptions = Get-AzSubscription

Write-Output "Found $($subscriptions.Count) subscriptions."

$privilegedUsers = @()

foreach ($subscription in $subscriptions)
{
    Write-Output "Analyzing $($subscription.Name) subscription..."
    Select-AzSubscription -SubscriptionId $subscription.Id | Out-Null

    $allRoles = Get-AzRoleDefinition
    $privilegedRoles = $allRoles | Where-Object { $_.Name -like "*owner*" -or $_.Name -like "*contributor*" -or $_.Name -like "*admin*" }
    
    $roleAssignments = Get-AzRoleAssignment
    $privilegedRoleAssignments = $roleAssignments | Where-Object { $_.ObjectType -eq "User" -and $_.RoleDefinitionId -in $privilegedRoles.Id}
    $nonPrivilegedRoleAssignments = $roleAssignments | Where-Object { $_.ObjectType -eq "User" -and -not($_.RoleDefinitionId -in $privilegedRoles.Id)}

    foreach ($assignment in $privilegedRoleAssignments)
    {
        $aadUser = $users | Where-Object { $_.ObjectId -eq $assignment.ObjectId}
        $msolUser = $msolUsers | Where-Object { $_.ObjectId -eq $assignment.ObjectId}
        $role = $privilegedRoles | Where-Object { $_.Id -eq $assignment.RoleDefinitionId }
        $logentry = New-Object PSObject -Property @{
            UserPrincipalName = $aadUser.UserPrincipalName
            UserPrincipalId = $aadUser.ObjectId
            SubscriptionId = $subscription.Id
            SubscriptionName = $subscription.Name
            RoleDefinitionId = $assignment.RoleDefinitionId
            RoleDefinitionName = $role.Name
            Scope = $assignment.Scope
            IsPrivileged = $true
            StrongAuthenticationEnabled = ($msolUser.StrongAuthenticationMethods.Count -gt 0)
        }
        $privilegedUsers += $logentry        
    }

    foreach ($assignment in $nonPrivilegedRoleAssignments)
    {
        $aadUser = $users | Where-Object { $_.ObjectId -eq $assignment.ObjectId}
        $msolUser = $msolUsers | Where-Object { $_.ObjectId -eq $assignment.ObjectId}
        $role = $allRoles | Where-Object { $_.Id -eq $assignment.RoleDefinitionId }
        $logentry = New-Object PSObject -Property @{
            UserPrincipalName = $aadUser.UserPrincipalName
            UserPrincipalId = $aadUser.ObjectId
            SubscriptionId = $subscription.Id
            SubscriptionName = $subscription.Name
            RoleDefinitionId = $assignment.RoleDefinitionId
            RoleDefinitionName = $role.Name
            Scope = $assignment.Scope
            IsPrivileged = $false
            StrongAuthenticationEnabled = ($msolUser.StrongAuthenticationMethods.Count -gt 0)
        }
        $privilegedUsers += $logentry        
    }
}

$datetime = Get-Date
$fileDate = $datetime.ToString("yyyyMMddHHmmss")
$csvExportPath = "privileged-users-mfa-state-$TenantId-$fileDate.csv"
$privilegedUsers | Export-Csv -Path $csvExportPath -NoTypeInformation

Write-Output "Successfully exported privileged users MFA state details to $csvExportPath!"

Write-Output "DONE!"
