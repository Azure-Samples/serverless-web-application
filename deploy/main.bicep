@description('Suffix for naming resources')
param appNameSuffix string = 'app${uniqueString(resourceGroup().id)}'

@allowed([
  'dev'
  'test'
  'prod'
])
@description('Environment')
param environmentType string = 'dev'

@description('Do you want to create new APIM?')
param createApim bool = true

@description('APIM name')
param apimName string = 'apim-${appNameSuffix}-${environmentType}'

@description('APIM resource group')
param apimResourceGroup string = resourceGroup().name

@description('Do you want to create new vault?')
param createKeyVault bool = true

@description('Key Vault name')
param keyVaultName string = 'kv-${appNameSuffix}-${environmentType}'

@description('Key Vault resource group')
param keyVaultResourceGroup string = resourceGroup().name

@description('User assigned managed idenity name')
param userAssignedIdentityName string = 'umsi-${appNameSuffix}-${environmentType}'

@description('User assigned managed idenity resource group')
param userAssignedIdentityResourceGroup string = resourceGroup().name

@description('API friendly name')
param apimApiName string = '2do'

param resourceTags object = {
  ProjectType: 'Azure Serverless Web'
  Purpose: 'Demo'
}

var location = resourceGroup().location
var staticWebsiteStorageAccountName = '${appNameSuffix}${environmentType}'
var cdnProfileName = 'cdn-${appNameSuffix}-${environmentType}'
var functionStorageAccountName = 'fn${appNameSuffix}${environmentType}'
var functionAppName = 'fn-${appNameSuffix}-${environmentType}'
var functionRuntime = 'dotnet'
var appServicePlanName = 'asp-${appNameSuffix}-${environmentType}'
var appInsightsName = 'ai-${appNameSuffix}-${environmentType}'
var cosmosDbName = '${appNameSuffix}-${environmentType}'
var cosmosDbAccountName = 'cosmos-${appNameSuffix}-${environmentType}'

// SKUs
var functionSku = environmentType == 'prod' ? 'EP1' : 'Y1'
var apimSku = environmentType == 'prod' ? 'Standard' : 'Developer'

// static values
var cosmosDbCollectionName = 'items'

// Use existing User Assigned MSI. See https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/deployment-script-template#configure-the-minimum-permissions
resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: userAssignedIdentityName
  scope: resourceGroup(userAssignedIdentityResourceGroup)
}

resource appInsights 'Microsoft.Insights/components@2018-05-01-preview' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

module staticWebsite 'modules/staticWebsite.bicep' = {
  name: 'staticWebsite'
  params: {
    storageAccountName: staticWebsiteStorageAccountName
    deploymentScriptServicePrincipalId: userAssignedIdentity.id
    resourceTags: resourceTags
  }
}

module cdn 'modules/cdn.bicep' = {
  name: 'cdn'
  params: {
    cdnProfileName: cdnProfileName
    staticWebsiteURL: staticWebsite.outputs.staticWebsiteURL
  }
}

module cosmosDB 'modules/cosmosdb.bicep' = {
  name: 'cosmosdb'
  params: {
    accountName: cosmosDbAccountName
    databaseName: cosmosDbName
    collectionName: cosmosDbCollectionName
  }
}

module functionApp 'modules/function.bicep' = {
  name: 'functionApp'
  params: {
    functionRuntime: functionRuntime
    functionSku: functionSku
    storageAccountName: functionStorageAccountName
    functionAppName: functionAppName
    appServicePlanName: appServicePlanName
    appInsightsInstrumentationKey: appInsights.properties.InstrumentationKey
    staticWebsiteURL: staticWebsite.outputs.staticWebsiteURL
    cosmosAccountName: cosmosDbAccountName
    cosmosDbName: cosmosDbName
    cosmosDbCollectionName: cosmosDbCollectionName
    keyVaultName: keyVaultName
    apimIPAddress: apim.outputs.apiIPAddress
    resourceTags: resourceTags
  }
}

module keyVault 'modules/keyVault.bicep' = if (!createKeyVault) {
  name: 'keyVault'
  scope: resourceGroup(keyVaultResourceGroup)
  params: {
    keyVaultName: keyVaultName
    functionAppName: functionApp.outputs.functionAppName
    cosmosAccountName: cosmosDB.outputs.cosmosDBAccountName
    deploymentScriptServicePrincipalId: userAssignedIdentity.id
    currentResourceGroup: resourceGroup().name
  }
}

module newKeyVault 'modules/newKeyVault.bicep' = if (createKeyVault) {
  name: 'newKeyVault'
  params: {
    keyVaultName: keyVaultName
    functionAppName: functionApp.outputs.functionAppName
    cosmosAccountName: cosmosDB.outputs.cosmosDBAccountName 
    deploymentScriptServicePrincipalId: userAssignedIdentity.id
    resourceTags: resourceTags
  }
}

module apim 'modules/apim.bicep' = if (createApim) {
  name: 'apim'
  params: {
    apimName: apimName
    appInsightsName: appInsightsName
    appInsightsInstrumentationKey: appInsights.properties.InstrumentationKey
    sku: apimSku
    resourceTags: resourceTags
  }
}

module apimApi 'modules/apimAPI.bicep' = {
  name: 'apimAPI'
  scope: resourceGroup(apimResourceGroup)
  params: {
    apimName: apimName
    currentResourceGroup: resourceGroup().name
    backendApiName: functionApp.outputs.functionAppName
    apiName: apimApiName
    originUrl: cdn.outputs.cdnEndpointURL
  }
}

output functionAppName string = functionApp.outputs.functionAppName
output apiUrl string = '${apim.outputs.gatewayUrl}/${apimApiName}'
output staticWebsiteStorageAccountName string = staticWebsiteStorageAccountName
output staticWebsiteUrl string = staticWebsite.outputs.staticWebsiteURL
output apimName string = apimName
output cdnEndpointName string = cdn.outputs.cdnEndpointName
output cdnProfileName string = cdn.outputs.cdnProfileName
output cdnEndpointURL string = cdn.outputs.cdnEndpointURL
