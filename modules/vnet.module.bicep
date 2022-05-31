param name string
param location string = resourceGroup().location
param tags object = {}
param addressPrefix string
param includeBastion bool = true

param defaultSnet object
param appSnet object
param devOpsSnet object
param bastionSnet object
param frontendIntegrationSnet object

var defaultSnetConfig = {
  name: '${name}-default-snet'
  properties: defaultSnet
}

var appSnetConfig = {
  name: '${name}-app-snet'
  properties: appSnet
}

var devOpsSnetConfig = {
  name: '${name}-devops-snet'
  properties: devOpsSnet
}

var bastionSnetConfig = {
  name: 'AzureBastionSubnet'
  properties: bastionSnet
}

var frontendIntegrationSnetConfig = {
  name: '${name}-frontend-integration-snet'
  properties: frontendIntegrationSnet
}

var fixedSubnets = [
  defaultSnetConfig
  appSnetConfig
  devOpsSnetConfig
  frontendIntegrationSnetConfig
]

var allSubnets = includeBastion ? union(fixedSubnets, [
  bastionSnetConfig
]) : fixedSubnets

resource vnet 'Microsoft.Network/virtualNetworks@2020-06-01' = {
  name: name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: allSubnets
  }
  tags: tags
}

output vnetId string = vnet.id
output defaultSnetId string = vnet.properties.subnets[0].id
output appSnetId string = vnet.properties.subnets[1].id
output devOpsSnetId string = vnet.properties.subnets[2].id
output frontendIntegrationSnetId string = vnet.properties.subnets[3].id
output bastionSnetId string = includeBastion ? vnet.properties.subnets[4].id : ''
