param location string = resourceGroup().location
param functionRuntime string
param functionSku string
param storageAccountName string
param functionAppName string
param appServicePlanName string
param appInsightsInstrumentationKey string
param staticWebsiteURL string
param cosmosAccountName string
param cosmosDbName string
param cosmosDbCollectionName string
param keyVaultName string
param apimIPAddress string
param resourceTags object


var functionTier = functionSku == 'Y1' ? 'Dynamic' : 'ElasticPremium'
var functionKind = functionSku == 'Y1' ? 'functionapp' : 'elastic'
var keyVaultSecretName = '${cosmosAccountName}-key'

resource storageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: storageAccountName
  location: location
  tags: resourceTags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
  }
}

resource plan 'Microsoft.Web/serverFarms@2020-06-01' = {
  name: appServicePlanName
  location: location
  kind: functionKind
  tags: resourceTags
  sku: {
    name: functionSku
    tier: functionTier
  }
  properties: {}
}

resource functionApp 'Microsoft.Web/sites@2020-06-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  tags: resourceTags
  properties: {
    serverFarmId: plan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsightsInstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: 'InstrumentationKey=${appInsightsInstrumentationKey}'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionRuntime
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'KEY_VAULT_URI'
          value: 'https://${keyVaultName}.vault.azure.net'
        }
        {
          name: 'CONNECTION_STRINGS'
          value: keyVaultSecretName
        }
        {
          name: 'DATABASE_NAME'
          value: cosmosDbName
        }
        {
          name: 'COLLECTION_NAME'
          value: cosmosDbCollectionName
        }
      ]
      cors: {
        allowedOrigins: [
          staticWebsiteURL
        ]
      }
      ipSecurityRestrictions: [
        {
          ipAddress: '${apimIPAddress}/32'
          action: 'Allow'
          priority: 100
          name: 'APIM'
          description: 'Traffic from APIM'
        }
        {
          ipAddress: 'Any'
          action: 'Deny'
          priority: 2147483647
          name: 'Deny all'
          description: 'Deny all access'
        }
      ]
    }
    httpsOnly: true
  }
  identity: {
    type: 'SystemAssigned'
  }  
}

output functionAppName string = functionApp.name
