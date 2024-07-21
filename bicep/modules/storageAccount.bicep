param name string
param location string
param tags object


resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: name
  location: location
  sku: {
    name: 'Standard_GRS'
  }
  kind: 'StorageV2'
  tags: tags
}

output primaryAccessKey string = storageAccount.listKeys().keys[0].value
output name string = storageAccount.name
output resourceId string = storageAccount.id
