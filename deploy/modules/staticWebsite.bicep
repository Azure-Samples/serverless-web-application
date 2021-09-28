param storageAccountName string
param resourceTags object
param deploymentScriptServicePrincipalId string

var location = resourceGroup().location

resource storageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: storageAccountName
  location: location
  tags: resourceTags
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
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

resource deploymentScripts 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'configStaticWeb'
  kind: 'AzurePowerShell'
  location: location
  identity:{
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${deploymentScriptServicePrincipalId}': {}
    }
  }
  properties: {
    azPowerShellVersion: '6.1'
    timeout: 'PT30M'
    arguments: '-storageAccount ${storageAccount.name} -resourceGroup ${resourceGroup().name}'
    scriptContent: '''
      param([string] $storageAccount, [string] $resourceGroup)
      $storage = Get-AzStorageAccount -ResourceGroupName $resourceGroup -Name $storageAccount
      $ctx = $storage.Context
      Enable-AzStorageStaticWebsite -Context $ctx -IndexDocument index.html -ErrorDocument404Path notfound.html
      $output = $storage.PrimaryEndpoints.Web
      $output = $output.TrimEnd('/')
      $DeploymentScriptOutputs = @{}
      $DeploymentScriptOutputs['URL'] = $output
    '''
    cleanupPreference: 'Always'
    retentionInterval: 'P1D'
  }
}

output staticWebsiteURL string = deploymentScripts.properties.outputs.URL
