param (
    [Parameter(Mandatory=$true)]
    [String] $TenantId,

    [Parameter(Mandatory=$false)]
    [String] $AzureEnvironment = "AzureCloud",

    [Parameter(Mandatory=$false)]
    [int] $DaysThreshold = 30,

    [Parameter(Mandatory=$false)]
    [ValidateSet("Group","User")]
    [String] $RoleObjectType = "Group",

    [Parameter(Mandatory=$true)]
    [String] $RoleObjectSearchString,

    [Parameter(Mandatory=$true)]
    [String] $LogAnalyticsWorkspaceId
)

$ErrorActionPreference = "Stop"

function IsUserMatching {
    param (
        [String] $UserString,
        [String[]] $UserList
    )

    foreach ($User in $UserList)
    {
        if ($UserString -eq $User)
        {
            return $true
        }
        if ($User.Contains("\"))
        {
            $User = $User.Split("\")[1]
            if ($UserString -eq $User)
            {
                return $true
            }
        }
    }

    return $false
}

$ctx = Get-AzContext
if (-not($ctx) -or $ctx.Environment.Name -ne $AzureEnvironment -or $ctx.Tenant.Id -ne $TenantId)
{
    $ctx = Connect-AzAccount -Environment $AzureEnvironment -TenantId $TenantId
}

$subscriptions = Get-AzSubscription -TenantId $TenantId | Where-Object { $_.State -eq "Enabled" } | ForEach-Object { "$($_.Id)"}

$ARGPageSize = 1000

$bastionsTotal = @()
$resultsSoFar = 0

Write-Output "Querying for Bastion Hosts properties"

$argQuery = @"
resources
| where type =~ 'microsoft.network/bastionhosts'
| project id, name, resourceGroup, subscriptionId
"@

do
{
    if ($resultsSoFar -eq 0)
    {
        $bastions = Search-AzGraph -Query $argQuery -First $ARGPageSize -Subscription $subscriptions
    }
    else
    {
        $bastions = Search-AzGraph -Query $argQuery -First $ARGPageSize -Skip $resultsSoFar -Subscription $subscriptions
    }
    if ($bastions -and $bastions.GetType().Name -eq "PSResourceGraphResponse")
    {
        $bastions = $bastions.Data
    }
    $resultsCount = $bastions.Count
    $resultsSoFar += $resultsCount
    $bastionsTotal += $bastions

} while ($resultsCount -eq $ARGPageSize)

Write-Output "Found $($bastionsTotal.Count) Bastion Hosts"

Write-Output "Getting Bastion access logs for the last $DaysThreshold days..."

$baseQuery = "MicrosoftAzureBastionAuditLogs | summarize LastSeen = max(TimeGenerated) by UserName, _ResourceId"

try
{
    $queryResults = Invoke-AzOperationalInsightsQuery -WorkspaceId $LogAnalyticsWorkspaceId -Query $baseQuery -Timespan (New-TimeSpan -Days $DaysThreshold) -Wait 600
    if ($queryResults)
    {
        $bastionAccessLogs = [System.Linq.Enumerable]::ToArray($queryResults.Results)        
    }
}
catch
{
    Write-Warning -Message "Query failed. Debug the following query in the Log Analytics workspace: $baseQuery"
}

Write-Output "Query finished with $($bastionAccessLogs.Count) results."

$notLoggingInUsers = @()

foreach ($bastion in $bastionsTotal) 
{
    $usersAssigned = @()

    $roleAssignments = Get-AzRoleAssignment -Scope $bastion.id | Where-Object { $_.ObjectType -eq $RoleObjectType }
    Write-Output "Found $($roleAssignments.Count) $RoleObjectType assignments for bastion $($bastion.name)."
    foreach ($assignment in $roleAssignments)
    {
        switch ($RoleObjectType)
        {
            "User" {
                $user = Get-AzADUser -ObjectId $assignment.ObjectId
                if ($user.UserPrincipalName -like "*$RoleObjectSearchString*")
                {
                    Write-Output "Found $($user.UserPrincipalName) user assignment."
                    $usersAssigned += $user.UserPrincipalName
                }
            }
            Default {
                $group = Get-AzADGroup -ObjectId $assignment.ObjectId
                if ($group.DisplayName -like "*$RoleObjectSearchString*")
                {
                    Write-Output "Found $($group.DisplayName) group assignment."
                    $groupMembers = Get-AzADGroupMember -GroupObjectId $group.Id
                    $usersAssigned += $groupMembers.UserPrincipalName
                }
            }
        }    
    }

    $usersAssigned = $usersAssigned | Select-Object -Unique

    #Write-Output "Users assigned role: $usersAssigned"

    $bastionUsersLoggedIn = ($bastionAccessLogs | Where-Object { $_._ResourceId -eq $bastion.id }).UserName

    #Write-Output "Users who logged in: $bastionUsersLoggedIn"

    foreach ($userAssigned in $usersAssigned)
    {
        if (-not($notLoggingInUsers | Where-Object { $_.UserName -eq $userAssigned -and $_.BastionID -eq $bastion.id}))
        {
            $username = $userAssigned.Split("@")[0]
            if (-not($bastionUsersLoggedIn) -or `
                (-not(IsUserMatching -UserString $userAssigned -UserList $bastionUsersLoggedIn) -and -not(IsUserMatching -UserString $username -UserList $bastionUsersLoggedIn)))
            {
                $userObj = New-Object PSObject -Property @{
                    UserName = $userAssigned
                    BastionID = $bastion.id
                }
                $notLoggingInUsers += $userObj
            }    
        }
    }
}

$notLoggingInUsers | Export-Csv -Path "notlogginginusers.csv" -NoTypeInformation