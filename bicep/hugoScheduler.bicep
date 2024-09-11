targetScope = 'subscription'

// Imported Values from deployHugoScheduler.ps1
param deployGuid string
param deployLocation string
param deployLocationShortCode string
param environmentType string
param projectName string

// Azure Governance Variables
param tags object = {
  Environment: environmentType
  LastUpdatedOn: utcNow('yyyy-MM-dd')
}

// Resource Group Variables
param newResourceGroupName string = 'rg-${projectName}-scheduler-${environmentType}-${deployLocationShortCode}'

// User Managed Identity Variables
param newUserManagedIdentityName string = 'mi-${projectName}-scheduler-${environmentType}-${deployLocationShortCode}'

// Key Vault Variables
param newKeyVaultName string = 'kv-${projectName}-scheduler-${environmentType}'

// Storage Account Variables
param newStorageAccountName string = 'sa${projectName}scheduler${environmentType}${deployLocationShortCode}'

// Application Insights Variables
param newAppInsightsName string = 'ai-${projectName}-scheduler-${environmentType}-${deployLocationShortCode}'

// Log Analytics Variables
param newLogAnalyticsName string = 'la-${projectName}-scheduler-${environmentType}-${deployLocationShortCode}'

// App Service Plan Variables
param newAppServicePlanName string = 'asp-${projectName}-scheduler-${environmentType}-${deployLocationShortCode}'

// Azure Function Variables
param newFunctionAppName string = 'func-${projectName}-scheduler-${environmentType}-${deployLocationShortCode}'
param FUNC_TIME_ZONE string = 'GMT Standard Time'

//
// NO HARD CODING UNDER THERE! K THANKS BYE 👋
//

// [AVM Module] - Resource Group
module createResourceGroup 'br/public:avm/res/resources/resource-group:0.3.0' = {
  name: 'createNewResourceGroup-${deployGuid}'
  params: {
    name: newResourceGroupName
    location: deployLocation
    tags: tags
  }
}

module createUserManagedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = {
  name: 'createUserManagedIdentity-${deployGuid}'
  scope: resourceGroup(newResourceGroupName)
  params: {
    name: newUserManagedIdentityName
    location: deployLocation
    tags: tags
  }
  dependsOn: [
    createResourceGroup
  ]
}

module createKeyVault 'br/public:avm/res/key-vault/vault:0.9.0' = {
  name: 'createKeyVault-${deployGuid}'
  scope: resourceGroup(newResourceGroupName)
  params: {
    name: newKeyVaultName
    location: deployLocation
    tags: tags
    enableRbacAuthorization: true
    enablePurgeProtection: false
    roleAssignments: [
      {
        principalId: createUserManagedIdentity.outputs.principalId
        roleDefinitionIdOrName: 'Key Vault Administrator'
        principalType: 'ServicePrincipal'
      }
      {
        principalId: createUserManagedIdentity.outputs.principalId
        roleDefinitionIdOrName: 'Key Vault Secrets Officer'
        principalType: 'ServicePrincipal'
      }
    ]
    secrets: [
      {
        name: 'github-token'
        value: 'github-token'
      }
      {
        name: 'github-owner'
        value: 'github-owner'
      }
      {
        name: 'github-repo'
        value: 'github-repo'
      }
    ]
  }
  dependsOn: [
    createResourceGroup
    createUserManagedIdentity
  ]
}

// [AVM Module] - Storage Account
module createStorageAccount 'br/public:avm/res/storage/storage-account:0.13.2' = {
  name: 'createStorageAccount-${deployGuid}'
  scope: resourceGroup(newResourceGroupName)
  params: {
    name: newStorageAccountName
    location: deployLocation
    skuName: 'Standard_GRS'
    minimumTlsVersion: 'TLS1_2'
    publicNetworkAccess: 'Enabled'
    allowSharedKeyAccess: true
    secretsExportConfiguration: {
      accessKey1: 'accessKey1'
      accessKey2: 'accessKey2'
      connectionString1: 'connectionString1'
      connectionString2: 'connectionString2'
      keyVaultResourceId: createKeyVault.outputs.resourceId
    }
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
    tags: tags
  }
  dependsOn: [
    createResourceGroup
    createKeyVault
  ]
}

// // [Bicep Custom Module] - Storage Account
// module createStorageAccount './modules/storageAccount.bicep' = {
//   scope: resourceGroup(newResourceGroupName)
//   name: 'createStorageAccount-${deployGuid}'
//   params: {
//     location: deployLocation
//     name: newStorageAccountName
//     tags: tags
//   }
//   dependsOn: [
//     createResourceGroup
//   ]
// }

// [AVM Module] - Log Analytics
module createLogAnalytics 'br/public:avm/res/operational-insights/workspace:0.6.0' = {
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
module createApplicationInsights 'br/public:avm/res/insights/component:0.4.1' = {
  name: 'createAppInsights-${deployGuid}'
  scope: resourceGroup(newResourceGroupName)
  params: {
    name: newAppInsightsName
    workspaceResourceId: createLogAnalytics.outputs.resourceId
    location: deployLocation
    tags: tags
  }
  dependsOn: [
    createResourceGroup
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
    kind: 'Linux'
    location: deployLocation
    tags: tags
  }
  dependsOn: [
    createResourceGroup
  ]
}

// [AVM Module] - Function App
module createFunctionApp 'br/public:avm/res/web/site:0.7.0' = {
  name: 'createFunctionApp-${deployGuid}'
  scope: resourceGroup(newResourceGroupName)
  params: {
    kind: 'functionapp,linux'
    name: newFunctionAppName
    location: deployLocation
    httpsOnly: true
    serverFarmResourceId: createAppServicePlan.outputs.resourceId
    appInsightResourceId: createApplicationInsights.outputs.resourceId
    keyVaultAccessIdentityResourceId: createUserManagedIdentity.outputs.resourceId
    storageAccountRequired: true
    storageAccountResourceId: createStorageAccount.outputs.resourceId
    managedIdentities: {
      userAssignedResourceIds: [
        createUserManagedIdentity.outputs.resourceId
      ]
    }
    appSettingsKeyValuePairs: {
      APPLICATIONINSIGHTS_CONNECTION_STRING: createApplicationInsights.outputs.connectionString
      //WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: 'DefaultEndpointsProtocol=https;AccountName=${createStorageAccount.outputs.name};AccountKey=${createStorageAccount.outputs.primaryAccessKey};EndpointSuffix=core.windows.net'
      //WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: '@Microsoft.KeyVault(SecretUri=${createStorageAccount.outputs.exportedSecrets.connectionString1.secretUri})'
      WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: '@Microsoft.KeyVault(VaultName=${newKeyVaultName};SecretName=connectionString1)'
      WEBSITE_CONTENTSHARE: newFunctionAppName
      FUNCTIONS_EXTENSION_VERSION: '~4'
      FUNCTIONS_WORKER_RUNTIME: 'powershell'
      WEBSITE_TIME_ZONE: FUNC_TIME_ZONE
      GITHUB_USER_TOKEN: '@Microsoft.KeyVault(VaultName=${newKeyVaultName};SecretName=github-token)'
      GITHUB_REPO_OWNER: '@Microsoft.KeyVault(VaultName=${newKeyVaultName};SecretName=github-owner)'
      GITHUB_REPO_NAME: '@Microsoft.KeyVault(VaultName=${newKeyVaultName};SecretName=github-repo)'
      GITHUB_DEFAULT_BRANCH: 'main'
    }
    siteConfig: {
      alwaysOn: false
      linuxFxVersion: 'POWERSHELL|7.4'
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
    createUserManagedIdentity
    createStorageAccount
  ]
}
