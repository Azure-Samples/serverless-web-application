param cdnProfileName string
param staticWebsiteURL string

var endpointName = replace(cdnProfileName,'cdn-','')
var staticWebsiteHostName = replace(replace(staticWebsiteURL,'https://',''),'/','')

resource cdnProfile 'Microsoft.Cdn/profiles@2020-04-15' = {
  name: cdnProfileName
  location: resourceGroup().location
  sku: { 
    name: 'Standard_Microsoft' 
  }
}

resource endpoint 'Microsoft.Cdn/profiles/endpoints@2020-04-15' = {
  parent: cdnProfile
  name: endpointName
  location: resourceGroup().location
  properties: {
    originHostHeader: staticWebsiteHostName
    isHttpAllowed: false
    isHttpsAllowed: true
    queryStringCachingBehavior: 'IgnoreQueryString'
    optimizationType: 'GeneralWebDelivery'
    contentTypesToCompress: [
      'text/plain'
      'text/html'
      'text/css'
      'text/javascript'
      'application/x-javascript'
      'application/javascript'
      'application/json'
      'application/xml'
    ]
    isCompressionEnabled: true
    origins: [
      {
        name: replace(staticWebsiteHostName,'.','-')
        properties: {
          hostName: staticWebsiteHostName
        }
      }
    ]
  }
}

output cdnEndpointURL string = 'https://${endpoint.properties.hostName}'
output cdnEndpointName string = endpoint.name
output cdnProfileName string = cdnProfile.name
