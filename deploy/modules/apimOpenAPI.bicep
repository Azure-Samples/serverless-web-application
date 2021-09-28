param apimName string
param openApiUrl string
param apiName string
param originUrl string

resource apim 'Microsoft.ApiManagement/service@2021-01-01-preview' existing = {
  name: apimName
}

resource api 'Microsoft.ApiManagement/service/apis@2021-01-01-preview' = {
  parent: apim
  name: apiName
  properties: {
    path: apiName
    displayName: apiName
    isCurrent: true
    subscriptionRequired: false
    format: 'swagger-link-json'
    value: openApiUrl //'https://name.azurewebsites.net/api/swagger.json'
    protocols: [
      'https'
    ]
  }
}

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2021-01-01-preview' = {
  parent: api
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: replace(loadTextContent('../content/cos-policy.xml'),'__ORIGIN__',originUrl)
  }
}
