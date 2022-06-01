param name string
param location string = resourceGroup().location
param tags object = {}
param appSettings array = []

@description('Whether to create a managed identity for the web app -defaults to \'false\'')
param managedIdentity bool = false

@allowed([
  'S1'
  'S2'
  'S3'
  'P1v3'
  'P2v3'
  'P3v3'
])
param skuName string = 'P1v3'

@description('The subnet Id to integrate the web app with -optional')
param subnetIdForIntegration string = ''

@description('Optional. The container to be deployed -fully qualified container tag expected.')
param containerApplicationTag string = ''

var skuTier =  substring(skuName, 0, 1) == 'S' ? 'Standard' : 'PremiumV3'
var webAppServicePlanName = 'plan-${name}'
var webAppInsName = 'appins-${name}'
var createNetworkConfig = !empty(subnetIdForIntegration)

var linuxFxVersion = empty(containerApplicationTag) ? 'DOCKER|mcr.microsoft.com/appsvc/staticsite:latest' : 'DOCKER|${containerApplicationTag}'

var networkConfigAppSettings = createNetworkConfig ? [
  {
    name: 'WEBSITE_PULL_IMAGE_OVER_VNET'
    value: 'true'
  }
  { 
    name: 'WEBSITE_DNS_SERVER'
    value: '168.63.129.16'
  }
] : []

module webAppIns './appInsights.module.bicep' = {
  name: webAppInsName
  params: {
    name: webAppInsName
    location: location
    tags: tags
    project: name
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2020-06-01' = {
  name: webAppServicePlanName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
  }
  kind: 'app,linux'
  properties: {
    reserved: true
  }
}

resource webApp 'Microsoft.Web/sites@2021-03-01' = {
  name: name
  location: location  
  identity: {
    type: managedIdentity ? 'SystemAssigned' : 'None'
  }
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {      
      linuxFxVersion: linuxFxVersion
      vnetRouteAllEnabled: true
      appSettings: concat([
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: webAppIns.outputs.instrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: 'InstrumentationKey=${webAppIns.outputs.instrumentationKey}'
        }
      ], networkConfigAppSettings, appSettings)
    }
    httpsOnly: true
  }
  tags: union({
    'hidden-related:${resourceGroup().id}/providers/Microsoft.Web/serverfarms/${appServicePlan.name}': 'Resource'
  }, tags)
}

resource networkConfig 'Microsoft.Web/sites/networkConfig@2020-06-01' = if (createNetworkConfig) {
  name: '${webApp.name}/VirtualNetwork'
  properties: {
    subnetResourceId: subnetIdForIntegration
  }
}

output id string = webApp.id
output name string = webApp.name
output appServicePlanId string = appServicePlan.id
output identity object = managedIdentity ? {
  tenantId: webApp.identity.tenantId
  principalId: webApp.identity.principalId
  type: webApp.identity.type
} : {}
output applicationInsights object = webAppIns
output siteHostName string = webApp.properties.defaultHostName
