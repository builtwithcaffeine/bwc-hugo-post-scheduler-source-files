<#
.SYNOPSIS
Deploy Hugo Scheduler

.DESCRIPTION
This script deploys the Hugo Scheduler using Azure CLI. It takes in parameters such as subscription ID, deployment location, environment type, and project name. It creates a new deployment GUID, sets the Azure subscription, and deploys the Hugo Scheduler using the specified parameters.

.PARAMETER subscriptionId
The subscription ID for the deployment.

.PARAMETER deployLocation
The location where the deployment will occur. Valid values are listed in the ValidateSet attribute.

.PARAMETER environmentType
The environment type for the deployment. Valid values are 'prod', 'acc', and 'dev'.

.PARAMETER projectName
The name of the project.

.EXAMPLE
deployHugoScheduler.ps1 -subscriptionId "12345678-1234-1234-1234-1234567890ab" -deployLocation "westeurope" -environmentType "prod" -projectName "hugo"

This example deploys the Hugo Scheduler to the "westeurope" location in the production environment for the project named "Hugo".

.NOTES
    This script requires the Azure CLI to be installed and logged in to an Azure subscription.
    File Name      : deployHugoScheduler.ps1
    Author         : Simon Lee - GitHub: @smoonlee - Twitter: @smoon_lee
    Prerequisite   : Microsoft.VisualStudioCode, Git.Git, Microsoft.AzureCLI, Microsoft.Bicep
#>
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
    [string] $environmentType,

    # Parameter help description
    [Parameter(Mandatory = $true)]
    [string] $projectName
)

# Location short codes
$locationShortCodes = @{
    "eastus"             = "eus"
    "eastus2"            = "eus2"
    "westus"             = "wus"
    "westus2"            = "wus2"
    "northcentralus"     = "ncu"
    "southcentralus"     = "scu"
    "centralus"          = "ceu"
    "canadacentral"      = "cac"
    "canadaeast"         = "cae"
    "brazilsouth"        = "sau"
    "northeurope"        = "neu"
    "westeurope"         = "weu"
    "uksouth"            = "uks"
    "ukwest"             = "ukw"
    "francecentral"      = "frc"
    "francesouth"        = "frs"
    "germanywestcentral" = "gwc"
    "germanynorth"       = "gen"
    "switzerlandnorth"   = "swn"
    "switzerlandwest"    = "sww"
    "norwayeast"         = "noe"
    "norwaywest"         = "now"
    "eastasia"           = "eas"
    "southeastasia"      = "sea"
    "japaneast"          = "jae"
    "japanwest"          = "jaw"
    "australiaeast"      = "aue"
    "australiasoutheast" = "aus"
    "centralindia"       = "cin"
    "southindia"         = "sin"
    "westindia"          = "win"
    "koreacentral"       = "koc"
    "koreasouth"         = "kos"
    "uaenorth"           = "uan"
    "uaecentral"         = "uac"
    "southafricanorth"   = "sna"
    "southafricawest"    = "saw"
}

# Import PowerShell Functions
Get-ChildItem -Path "$PSScriptRoot\functions" -Filter *.ps1 | ForEach-Object {
    . $_.FullName
}

# Check Project Name Length
checkProjectName -projectName $projectName

# Set Azure Subscription
az account set --subscription $subscriptionId

# Retrieve subscription ID using Azure CLI
$subscriptionId = az account show --query id -o tsv

# Retrieve User Account using Azure CLI
$userAccount = az account show --query user.name -o tsv
$userAccountGuid = az ad signed-in-user show --query id -o tsv

# Get location short code
$deployLocationShortCode = $locationShortCodes[$deployLocation]

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
    deployLocationShortCode=$deployLocationShortCode `
    environmentType=$environmentType `
    deployGuid=$deployGuid `
    deployedBy=$userAccount `
    projectName=$projectName `
    userAccountGuid=$userAccountGuid `
    --confirm-with-what-if `
    --output none

#
$endTimeStamp = Get-Date -Format 'HH:mm:ss'
$timeDifference = New-TimeSpan -Start $startTimeStamp -End $endTimeStamp ; $deploymentDuration = "{0:hh\:mm\:ss}" -f $timeDifference

Write-Output "Hugo Scheduler - Deployment Completed: $endTimeStamp - Deployment Duration: $deploymentDuration"