targetScope = 'subscription'

// Imported Values from deployHugoScheduler.ps1
param deployGuid string
param deployLocation string
param deployLocationShortCode string
param deployedBy string
param environmentType string
param projectName string
param userAccountGuid string

// Azure Governance Variables
param tags object = {
  Environment: environmentType
  LastUpdatedOn: utcNow('yyyy-MM-dd')
  deployedBy: deployedBy
}

// Resource Group Variables
param resourceGroupName string = 'rg-${projectName}-scheduler-${environmentType}-${deployLocationShortCode}'

// User Managed Identity Variables
param userManagedIdentityName string = 'id-${projectName}-scheduler-${environmentType}-${deployLocationShortCode}'

// Key Vault Variables
param keyvaultName string = 'kv-${projectName}-scheduler-${environmentType}'
param kvSoftDeleteRetentionInDays int = 7
param kvNetworkAcls object = {
  bypass: 'AzureServices'
  defaultAction: 'Allow'
}
param kvSecretArray array = [
  {
    name: 'githubUserToken'
    value: 'github-token'
  }
  {
    name: 'githubRepoOwner'
    value: 'github-owner'
  }
  {
    name: 'githubRepoName'
    value: 'github-repo'
  }
]

// Storage Account Variables
param storageAccountName string = 'sa${projectName}scheduler${environmentType}${deployLocationShortCode}'
param stSkuName string = 'Standard_GRS'
param stTlsVersion string = 'TLS1_2'
param stPublicNetworkAccess string = 'Enabled'
param stAllowedSharedKeyAccess bool = true
param stNetworkAcls object = {
  bypass: 'AzureServices'
  defaultAction: 'Allow'
}

// Log Analytics Variables
param logAnalyticsName string = 'la-${projectName}-scheduler-${environmentType}-${deployLocationShortCode}'

// Application Insights Variables
param appInsightsName string = 'ai-${projectName}-scheduler-${environmentType}-${deployLocationShortCode}'

// App Service Plan Variables
param newAppServicePlanName string = 'asp-${projectName}-scheduler-${environmentType}-${deployLocationShortCode}'
param aspCapacity int = 1
param aspSkuName string = 'Y1'
param aspKind string = 'Linux'

// Azure Function Variables
param functionAppName string = 'func-${projectName}-scheduler-${environmentType}-${deployLocationShortCode}'

//
// NO HARD CODING UNDER THERE! K THANKS BYE 👋
//

// [AVM Module] - Resource Group
module createResourceGroup 'br/public:avm/res/resources/resource-group:0.4.0' = {
  name: 'createResourceGroup-${deployGuid}'
  params: {
    name: resourceGroupName
    location: deployLocation
    tags: tags
  }
}

module createUserManagedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = {
  name: 'createUserManagedIdentity-${deployGuid}'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: userManagedIdentityName
    location: deployLocation
    tags: tags
  }
  dependsOn: [
    createResourceGroup
  ]
}

// [AVM] - Key Vault
module createKeyVault 'br/public:avm/res/key-vault/vault:0.9.0' = {
  name: 'createKeyVault-${deployGuid}'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: keyvaultName
    sku: 'standard'
    location: deployLocation
    tags: tags
    enableRbacAuthorization: true
    enablePurgeProtection: false
    softDeleteRetentionInDays: kvSoftDeleteRetentionInDays
    networkAcls: kvNetworkAcls
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
      {
        principalId: userAccountGuid
        roleDefinitionIdOrName: 'Key Vault Administrator'
        principalType: 'User'
      }
      {
        principalId: userAccountGuid
        roleDefinitionIdOrName: 'Key Vault Secrets Officer'
        principalType: 'User'
      }
    ]
    secrets: kvSecretArray
  }
  dependsOn: [
    createResourceGroup
    createUserManagedIdentity
  ]
}

// [AVM Module] - Storage Account
module createStorageAccount 'br/public:avm/res/storage/storage-account:0.13.2' = {
  name: 'createStorageAccount-${deployGuid}'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: storageAccountName
    location: deployLocation
    skuName: stSkuName
    minimumTlsVersion: stTlsVersion
    publicNetworkAccess: stPublicNetworkAccess
    allowSharedKeyAccess: stAllowedSharedKeyAccess
    secretsExportConfiguration: {
      accessKey1: 'accessKey1'
      accessKey2: 'accessKey2'
      connectionString1: 'connectionString1'
      connectionString2: 'connectionString2'
      keyVaultResourceId: createKeyVault.outputs.resourceId
    }
    networkAcls: stNetworkAcls
    tags: tags
  }
  dependsOn: [
    createResourceGroup
    createKeyVault
  ]
}

// [AVM Module] - Log Analytics
module createLogAnalytics 'br/public:avm/res/operational-insights/workspace:0.7.0' = {
  name: 'createLogAnalytics-${deployGuid}'
  scope: resourceGroup(resourceGroupName)
  params: {
    name: logAnalyticsName
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
  scope: resourceGroup(resourceGroupName)
  params: {
    name: appInsightsName
    workspaceResourceId: createLogAnalytics.outputs.resourceId
    location: deployLocation
    tags: tags
  }
  dependsOn: [
    createResourceGroup
  ]
}

// [AVM Module] - App Service Plan
module createAppServicePlan 'br/public:avm/res/web/serverfarm:0.2.3' = {
  scope: resourceGroup(resourceGroupName)
  name: 'createServerFarmDeployment-${deployGuid}'
  params: {
    name: newAppServicePlanName
    skuCapacity: aspCapacity
    skuName: aspSkuName
    kind: aspKind
    location: deployLocation
    tags: tags
  }
  dependsOn: [
    createResourceGroup
  ]
}

// [AVM Module] - Function App
module createFunctionApp 'br/public:avm/res/web/site:0.9.0' = {
  name: 'createFunctionApp-${deployGuid}'
  scope: resourceGroup(resourceGroupName)
  params: {
    kind: 'functionapp,linux'
    name: functionAppName
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
      WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: '@Microsoft.KeyVault(VaultName=${keyvaultName};SecretName=connectionString1)'
      WEBSITE_CONTENTSHARE: functionAppName
      FUNCTIONS_EXTENSION_VERSION: '~4'
      FUNCTIONS_WORKER_RUNTIME: 'powershell'
      GITHUB_USER_TOKEN: '@Microsoft.KeyVault(VaultName=${keyvaultName};SecretName=githubUserToken)'
      GITHUB_REPO_OWNER: '@Microsoft.KeyVault(VaultName=${keyvaultName};SecretName=githubRepoOwner)'
      GITHUB_REPO_NAME: '@Microsoft.KeyVault(VaultName=${keyvaultName};SecretName=githubRepoName)'
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
