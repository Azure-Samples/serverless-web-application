@description('APIM name')
param apimName string

@description('Open API Definition URL')
param openApiUrl string

@description('Static Website URL')
param originUrl string

@description('API friendly name')
param apimApiName string = '2do'

module apimOpenApi 'modules/apimOpenAPI.bicep' = {
  name: 'apimOpenAPI'
  params: {
    apimName: apimName
    openApiUrl: openApiUrl
    apiName: apimApiName
    originUrl: originUrl
  }
}
