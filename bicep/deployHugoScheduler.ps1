param (
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "The subscription ID for the deployment.")]
    [string] $subscriptionId,

    [Parameter(Mandatory = $true, Position = 1, HelpMessage = "The location where the deployment will occur.")]
    [ValidateSet(
        "eastus", "eastus2", "westus", "westus2",
        "northcentralus", "southcentralus", "centralus",
        "canadacentral", "canadaeast", "brazilsouth",
        "northeurope", "westeurope", "uksouth", "ukwest",
        "francecentral", "francesouth", "germanywestcentral",
        "germanynorth", "switzerlandnorth", "switzerlandwest",
        "norwayeast", "norwaywest", "eastasia", "southeastasia",
        "japaneast", "japanwest", "australiaeast",
        "australiasoutheast", "centralindia", "southindia",
        "westindia", "koreacentral", "koreasouth", "uaenorth",
        "uaecentral", "southafricanorth", "southafricawest"
    )]
    [string] $deployLocation,

    [Parameter(Mandatory = $true, Position = 2, HelpMessage = "The environment type for the deployment. Valid values are 'prod', 'acc', and 'dev'.")]
    [ValidateSet('prod', 'acc', 'dev')]
    [string] $environmentType
)

# Location short codes
$locationShortCodes = @{
    "eastus" = "eus"
    "eastus2" = "eus2"
    "westus" = "wus"
    "westus2" = "wus2"
    "northcentralus" = "ncu"
    "southcentralus" = "scu"
    "centralus" = "ceu"
    "canadacentral" = "cac"
    "canadaeast" = "cae"
    "brazilsouth" = "sau"
    "northeurope" = "neu"
    "westeurope" = "weu"
    "uksouth" = "uks"
    "ukwest" = "ukw"
    "francecentral" = "frc"
    "francesouth" = "frs"
    "germanywestcentral" = "gwc"
    "germanynorth" = "gen"
    "switzerlandnorth" = "swn"
    "switzerlandwest" = "sww"
    "norwayeast" = "noe"
    "norwaywest" = "now"
    "eastasia" = "eas"
    "southeastasia" = "sea"
    "japaneast" = "jae"
    "japanwest" = "jaw"
    "australiaeast" = "aue"
    "australiasoutheast" = "aus"
    "centralindia" = "cin"
    "southindia" = "sin"
    "westindia" = "win"
    "koreacentral" = "koc"
    "koreasouth" = "kos"
    "uaenorth" = "uan"
    "uaecentral" = "uac"
    "southafricanorth" = "sna"
    "southafricawest" = "saw"
}

# Set Azure Subscription
az account set --subscription $subscriptionId

# Retrieve subscription ID using Azure CLI
$subscriptionId = az account show --query id -o tsv

# Get location short code
$deploylocationShortCode = $locationShortCodes[$deployLocation]

# Generate deployment GUID
$startTimeStamp = Get-Date -Format 'HH:mm:ss'
$deployGuid = New-Guid

Write-Output `r "Hugo Scheduler - Deployment Starting: $startTimeStamp"
Write-Output "[IaC] :: Creating new Deployment Guid :: $deployGuid"

# Deploy using Azure CLI
az deployment sub create `
    --name hugo-$deployGuid `
    --location $deployLocation `
    --template-file ./hugoScheduler.bicep `
    --parameters deployLocation=$deployLocation `
                 deployLocationShortCode=$deploylocationShortCode `
                 environmentType=$environmentType `
                 deployGuid=$deployGuid `
    --confirm-with-what-if `
    --output none

#
$endTimeStamp = Get-Date -Format 'HH:mm:ss'
$timeDifference = New-TimeSpan -Start $startTimeStamp -End $endTimeStamp ;  $deploymentDuration = "{0:hh\:mm\:ss}" -f $timeDifference

Write-Output "Hugo Scheduler - Deployment Completed: $endTimeStamp - Deployment Duration: $deploymentDuration"