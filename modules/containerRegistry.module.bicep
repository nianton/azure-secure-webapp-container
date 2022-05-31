param name string
param location string
param tags object = {}
param zoneRedundant bool = false

@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param skuName string = 'Standard'

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-12-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  properties: {
    adminUserEnabled: true
    publicNetworkAccess: 'Enabled'
    zoneRedundancy: zoneRedundant ? 'Enabled' : 'Disabled'
    anonymousPullEnabled: false
    networkRuleBypassOptions: 'AzureServices'
  }
}

output id string = containerRegistry.id
output name string = containerRegistry.name
output apiVersion string = containerRegistry.apiVersion
output loginServer string = containerRegistry.properties.loginServer
