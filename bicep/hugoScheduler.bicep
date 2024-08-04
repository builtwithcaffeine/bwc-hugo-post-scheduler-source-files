targetScope = 'subscription'

// Imported Values from deployHugoScheduler.ps1
param deployGuid string
param deployLocation string
param deployLocationShortCode string
param environmentType string

// Azure Governance Variables
param tags object = {
  Environment: environmentType
  LastUpdatedOn: utcNow('d')
}

// Resource Group Variables
param newResourceGroupName string = 'rg-hugo-scheduler-${environmentType}-${deployLocationShortCode}'

// Storage Account Variables
param newStorageAccountName string = 'sahugoscheduler${environmentType}${deployLocationShortCode}'

// Application Insights Variables
param newAppInsightsName string = 'ai-hugo-scheduler-${environmentType}-${deployLocationShortCode}'

// Log Analytics Variables
param newLogAnalyticsName string = 'la-hugo-scheduler-${environmentType}-${deployLocationShortCode}'

// App Service Plan Variables
param newAppServicePlanName string = 'asp-hugo-scheduler-${environmentType}-${deployLocationShortCode}'

// Azure Function Variables
param newFunctionAppName string = 'func-hugo-scheduler-${environmentType}-${deployLocationShortCode}'
param FUNC_TIME_ZONE string = 'GMT Standard Time'

//
// NO HARD CODING UNDER THERE! K THANKS BYE 👋
//

// [AVM Module] - Resource Group
module createResourceGroup 'br/public:avm/res/resources/resource-group:0.2.4' = {
  name: 'createNewResourceGroup-${deployGuid}'
  params: {
    name: newResourceGroupName
    location: deployLocation
    tags: tags
  }
}

// [AVM Module] - Storage Account
// module createStorageAccount1 'br/public:avm/res/storage/storage-account:0.11.0' = {
//   name: 'createStorageAccount-${deployGuid}'
//   scope: resourceGroup(newResourceGroupName)
//   params: {
//     name: newStorageAccountName
//     location: deployLocation
//     skuName: 'Standard_GRS'
//     minimumTlsVersion: 'TLS1_2'
//     allowSharedKeyAccess: true
//     tags: tags
//   }
//   dependsOn: [
//     createResourceGroup
//   ]
// }

// [Bicep Custom Module] - Storage Account
module createStorageAccount './modules/storageAccount.bicep' = {
  scope: resourceGroup(newResourceGroupName)
  name: 'createStorageAccount-${deployGuid}'
  params: {
    location: deployLocation
    name: newStorageAccountName
    tags: tags
  }
  dependsOn: [
    createResourceGroup
  ]
}

// [AVM Module] - Log Analytics
module createLogAnalytics 'br/public:avm/res/operational-insights/workspace:0.4.0' = {
  name: 'createLogAnalytics-${deployGuid}'
  scope: resourceGroup(newResourceGroupName)
  params: {
    name: newLogAnalyticsName
    location: deployLocation
    tags: tags
  }
  dependsOn: [
    createResourceGroup
  ]
}

// [AVM Module] - Application Insights
module createApplicationInsights 'br/public:avm/res/insights/component:0.3.1' = {
  name: 'createAppInsights-${deployGuid}'
  scope: resourceGroup(newResourceGroupName)
  params: {
    // Required parameters
    name: newAppInsightsName
    workspaceResourceId: createLogAnalytics.outputs.resourceId
    location: deployLocation
    tags: tags
  }
  dependsOn: [
    createResourceGroup
    createLogAnalytics
  ]
}

// [AVM Module] - App Service Environment
module createAppServicePlan 'br/public:avm/res/web/serverfarm:0.2.2' = {
  scope: resourceGroup(newResourceGroupName)
  name: 'createServerFarmDeployment-${deployGuid}'
  params: {
    name: newAppServicePlanName
    skuCapacity: 1
    skuName: 'Y1'
    kind: 'Windows'
    location: deployLocation
    tags: tags
  }
  dependsOn: [
    createResourceGroup
    createStorageAccount
    createLogAnalytics
    createApplicationInsights
  ]
}

// [AVM Module] - Function App
module createFunctionApp 'br/public:avm/res/web/site:0.3.9' = {
  name: 'createFunctionApp-${deployGuid}'
  scope: resourceGroup(newResourceGroupName)
  params: {
    kind: 'functionapp'
    name: newFunctionAppName
    location: deployLocation
    storageAccountResourceId: createStorageAccount.outputs.resourceId
    httpsOnly: true
    serverFarmResourceId: createAppServicePlan.outputs.resourceId
    appInsightResourceId: createApplicationInsights.outputs.resourceId
    appSettingsKeyValuePairs: {
      APPLICATIONINSIGHTS_CONNECTION_STRING: createApplicationInsights.outputs.connectionString
      WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: 'DefaultEndpointsProtocol=https;AccountName=${createStorageAccount.outputs.name};AccountKey=${createStorageAccount.outputs.primaryAccessKey};EndpointSuffix=core.windows.net'
      WEBSITE_CONTENTSHARE: newFunctionAppName
      FUNCTIONS_EXTENSION_VERSION: '~4'
      FUNCTIONS_WORKER_RUNTIME: 'powershell'
      WEBSITE_TIME_ZONE: FUNC_TIME_ZONE
      GITHUB_USER_TOKEN: 'github-token'
      GITHUB_REPO_OWNER: 'github-owner'
      GITHUB_REPO_NAME: 'github-repo'
      GITHUB_DEFAULT_BRANCH: 'main'
    }
    siteConfig: {
      alwaysOn: false
      powershellVersion: '7.4'
      ftpsState: 'Disabled'
      http20Enabled: true
      minTlsVersion: '1.3'
      use32BitWorkerProcess: false
      cors: {
        allowedOrigins: ['*']
      }
    }
    basicPublishingCredentialsPolicies: [
      {
        allow: false
        name: 'ftp'
      }
      {
        allow: true
        name: 'scm'
      }
    ]
    logsConfiguration: {
      applicationLogs: {
        fileSystem: {
          level: 'Verbose'
        }
      }
      detailedErrorMessages: {
        enabled: true
      }
      failedRequestsTracing: {
        enabled: true
      }
      httpLogs: {
        fileSystem: {
          enabled: true
          retentionInDays: 1
          retentionInMb: 35
        }
      }
    }
    tags: tags
  }
  dependsOn: [
    createAppServicePlan
    createResourceGroup
    createStorageAccount
  ]
}
