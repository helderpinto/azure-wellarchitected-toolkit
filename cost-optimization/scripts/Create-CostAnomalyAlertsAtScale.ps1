param(
    [Parameter(Mandatory = $false)]
    [string] $Cloud = "AzureCloud",

    [Parameter(Mandatory = $false)]
    [string] $TargetSubscriptionId,

    [Parameter(Mandatory = $false)]
    [string] $AlertDisplayName = "Daily anomaly by resource group",

    [Parameter(Mandatory = $false)]
    [string] $SubjectPrefix = "Cost anomaly detected in ",

    [Parameter(Mandatory = $false)]
    [string] $Message = "",

    [Parameter(Mandatory = $false)]
    [string] $MessageLanguage = "en-us",
    
    [Parameter(Mandatory = $true)]
    [string[]] $Recipients,

    [Parameter(Mandatory = $false)]
    [switch] $Simulate
)

$ctx = Get-AzContext

if (-not($ctx)) {
    $ctx = Connect-AzAccount -Environment $Cloud
}

if ($TargetSubscriptionId)
{
    $subscriptions = Get-AzSubscription | Where-Object { $_.Id -eq $TargetSubscriptionId }
}
else
{
    $subscriptions = Get-AzSubscription | Where-Object { $_.State -eq "Enabled" }
}

foreach ($subscription in $subscriptions)
{
    $scheduledActionsResponse = Invoke-AzRestMethod -Method Get -Uri "https://management.azure.com/subscriptions/$($subscription.Id)/providers/Microsoft.CostManagement/scheduledActions?api-version=2023-11-01"
    if ($scheduledActionsResponse.StatusCode -eq 200)
    {
        $scheduledActions = ($scheduledActionsResponse.Content | ConvertFrom-Json).value
        $anomalyAlerts = $scheduledActions | Where-Object { `
            $_.properties.viewId -eq "/subscriptions/$($subscription.Id)/providers/Microsoft.CostManagement/views/ms:DailyAnomalyByResourceGroup" `
            -and $_.properties.status -eq "Enabled"
        }
        if ($anomalyAlerts.Count -eq 0)
        {
            Write-Output "Creating cost anomaly alert for subscription $($subscription.Name)..."
            $now = (Get-Date).ToUniversalTime()
            $nowUTC = $now.ToString("yyyy-MM-ddTHH:mm:ssZ")
            $oneYearLaterUTC = $now.AddYears(1).ToString("yyyy-MM-ddTHH:mm:ssZ")

            $alertSchedule = @{
                frequency = "Daily"
                startDate = $nowUTC
                endDate = $oneYearLaterUTC
            }
            $alertNotification = @{
                to = $Recipients
                subject = $SubjectPrefix + $subscription.Name
                message = $Message
                language = $MessageLanguage
            }
            $alertProperties = @{
                displayName = $AlertDisplayName
                status = "Enabled"
                viewId = "/subscriptions/$($subscription.Id)/providers/Microsoft.CostManagement/views/ms:DailyAnomalyByResourceGroup"
                schedule = $alertSchedule
                notification = $alertNotification
            }
            $alert = @{
                kind = "InsightAlert"
                properties = $alertProperties
            }
            if (-not($Simulate))
            {
                $createAlertResponse = Invoke-AzRestMethod -Method Put -Uri "https://management.azure.com/subscriptions/$($subscription.Id)/providers/Microsoft.CostManagement/scheduledActions/dailyanomalybyresourcegroup?api-version=2022-10-01" -Payload ($alert | ConvertTo-Json -Depth 3)
                if ($createAlertResponse.StatusCode -in (200, 201))
                {
                    Write-Output "Successfully created cost anomaly alert for subscription $($subscription.Name)."
                }
                else
                {
                    Write-Error "Failed to create cost anomaly alert for subscription $($subscription.Name). Status code: $($createAlertResponse.StatusCode)."
                }
            }
            else
            {
                Write-Output "Simulated creation of cost anomaly alert for subscription $($subscription.Name)."
            }
        }
        else
        {
            Write-Output "Cost anomaly alert already exists for subscription $($subscription.Name)."
        }
    }
    else
    {
        Write-Error "Failed to retrieve scheduled actions for subscription $($subscription.Name). Status code: $($scheduledActionsResponse.StatusCode)."
    }
}