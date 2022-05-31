param naming object
param location string = resourceGroup().location
param tags object

@secure()
param jumphostAdministratorPassword string

@secure()
param sqlServerAdministratorPassword string

var resourceNames = {
  applicationGateway: naming.applicationGateway.name
  bastion: naming.bastionHost.name
  containerRegistry: naming.containerRegistry.name
  frontendWebApp: replace(naming.appService.name, '${naming.appService.slug}-', '${naming.appService.slug}-frontend-')
  storageAccount: naming.storageAccount.nameUnique
  vnet: naming.virtualNetwork.name
  keyVault: naming.keyVault.nameUnique
  sqlServer: naming.mssqlServer.name
  sqlDatabase: naming.mssqlDatabase.name
  jumphostVirtualMachine: naming.windowsVirtualMachine.name
}
var sqlServerAdministratorLogin = 'dbadmin'
var isProd = contains(resourceGroup().name, 'prod')

var secretNames = {
  dataStorageConnectionString: 'dataStorageConnectionString'
  sqlConnectionString: 'sqlConnectionString'
  acrUsername: 'acrUsername'
  acrPassword: 'acrPassword'
}

module vnet 'modules/vnet.module.bicep' = {
  name: 'vnet-deployment'
  params: {
    name: resourceNames.vnet
    location: location
    tags: tags
    addressPrefix: isProd ? '10.11.0.0/23' : '10.10.0.0/23'
    defaultSnet: {
      addressPrefix: isProd ? '10.11.0.0/24' : '10.10.0.0/24'
    }
    appSnet: {
      addressPrefix: isProd ? '10.11.1.0/26' : '10.10.1.0/26'
      privateEndpointNetworkPolicies: 'Disabled'
    }
    devOpsSnet: {
      addressPrefix: isProd ? '10.11.1.64/27' : '10.10.1.64/27'
    }
    frontendIntegrationSnet: {
      addressPrefix: isProd ? '10.11.1.96/27' : '10.10.1.96/27'
      delegations: [
        {
          name: 'delegation'
          properties: {
            serviceName: 'Microsoft.Web/serverfarms'
          }
        }
      ]
      privateEndpointNetworkPolicies: 'Enabled'
    }
    bastionSnet: {
      addressPrefix: isProd ? '10.11.1.128/27' : '10.10.1.128/27'
    }
  }
}

module storage 'modules/storage.module.bicep' = {
  name: 'storage-deployment'
  params: {
    location: location
    kind: 'StorageV2'
    skuName: 'Standard_LRS'
    name: resourceNames.storageAccount
    tags: tags
  }
}

module containerRegistry 'modules/containerRegistry.module.bicep' = {
  name: 'containerRegistry-deployment'
  params: {
    name: resourceNames.containerRegistry
    location: location
    tags: tags
    skuName: 'Premium'
  }
}

module containerRegistryPrivateDnsZone 'modules/privateDnsZone.module.bicep' = {
  name: 'containerRegistryPrivateDnsZone-deployment'
  params: {
    name: 'privatelink.azurecr.io'
    vnetIds: [
      vnet.outputs.vnetId
    ]
  }
}

module containerRegistryPrivateEndpoint 'modules/privateEndpoint.module.bicep' = {
  name: 'containerRegistryPrivateEndpoint-deployment'
  params: {
    name: 'pe-${containerRegistry.outputs.name}'
    location: location
    tags: tags
    privateDnsZoneId: containerRegistryPrivateDnsZone.outputs.id
    privateLinkServiceId: containerRegistry.outputs.id
    subnetId: vnet.outputs.appSnetId
    subResource: 'registry'
  }
}

module frontendWebApp 'modules/webAppForContainers.module.bicep' = {
  name: 'frontendWebApp-deployment'
  params: {
    name: resourceNames.frontendWebApp
    location: location
    tags: tags
    skuName: 'S1'
    subnetIdForIntegration: vnet.outputs.frontendIntegrationSnetId
    managedIdentity: true
    appSettings: [
      {
        name: 'StorageConnection'
        value: '@Microsoft.KeyVault(VaultName=${resourceNames.keyVault};SecretName=${secretNames.dataStorageConnectionString})'
      }
      {
        name: 'SqlDbConnection'
        value: '@Microsoft.KeyVault(VaultName=${resourceNames.keyVault};SecretName=${secretNames.sqlConnectionString})'
      }
    ]
  }
}

module websitesPrivateDnsZone 'modules/privateDnsZone.module.bicep' = {
  name: 'websitesPrivateDnsZone-deployment'
  params: {
    name: 'privatelink.azurewebsites.net'
    vnetIds: [
      vnet.outputs.vnetId
    ]
  }
}

module frontendPrivateEndpoint 'modules/privateEndpoint.module.bicep' = {
  name: 'frontendPrivateEndpoint-deployment'
  params: {
    name: 'pe-${frontendWebApp.outputs.name}'
    location: location
    tags: tags
    privateDnsZoneId: websitesPrivateDnsZone.outputs.id
    privateLinkServiceId: frontendWebApp.outputs.id
    subnetId: vnet.outputs.appSnetId
    subResource: 'sites'
  }
}

module sqlServer 'modules/sqlServer.module.bicep' = {
  name: 'sqlServer-deployment'
  params: {
    name: resourceNames.sqlServer
    location: location
    tags: tags
    administratorLogin: sqlServerAdministratorLogin
    administratorLoginPassword: sqlServerAdministratorPassword
    databaseName: resourceNames.sqlDatabase
    databaseSkuName: 'S1'
  }
}

module sqlServerPrivateDnsZone 'modules/privateDnsZone.module.bicep' = {
  name: 'sqlServerPrivateDnsZone-deployment'
  params: {
    name: 'privatelink${environment().suffixes.sqlServerHostname}'
    vnetIds: [
      vnet.outputs.vnetId
    ]
  }
}

module sqlServerPrivateEndpoint 'modules/privateEndpoint.module.bicep' = {
  name: 'sqlServerPrivateEndpoint-deployment'
  params: {
    name: 'pe-${resourceNames.sqlServer}'
    location: location
    tags: tags
    privateDnsZoneId: sqlServerPrivateDnsZone.outputs.id
    privateLinkServiceId: sqlServer.outputs.id
    subnetId: vnet.outputs.appSnetId
    subResource: 'sqlServer'
  }
}

module keyVault 'modules/keyvault.module.bicep' = {
  name: 'keyVault-deployment'
  params: {
    name: resourceNames.keyVault
    location: location
    skuName: 'premium'
    tags: tags
    accessPolicies: [
      {
        tenantId: frontendWebApp.outputs.identity.tenantId
        objectId: frontendWebApp.outputs.identity.principalId
        permissions: {
          secrets: [
            'get'
          ]
        }
      }
    ]
    secrets: [
      {
        name: secretNames.dataStorageConnectionString
        service: {
          type: 'storageAccount'
          name: storage.outputs.name
          id: storage.outputs.id
          apiVersion: storage.outputs.apiVersion
        }
      }
      {
        name: secretNames.acrUsername
        service: {
          type: 'containerRegistry'
          secretType: 'username'
          name: containerRegistry.outputs.name
          id: containerRegistry.outputs.id
          apiVersion: containerRegistry.outputs.apiVersion
        }
      }
      {
        name: secretNames.acrPassword
        service: {
          type: 'containerRegistry'
          secretType: 'password'
          name: containerRegistry.outputs.name
          id: containerRegistry.outputs.id
          apiVersion: containerRegistry.outputs.apiVersion
        }
      }
      {
        name: secretNames.sqlConnectionString
        value: 'Data Source=tcp:${sqlServer.outputs.fullyQualifiedDomainName}, 1433;Initial Catalog=${resourceNames.sqlDatabase};User Id=${sqlServerAdministratorLogin}@${resourceNames.sqlServer};Password=${sqlServerAdministratorPassword};'
      }
    ]
  }
}

module jumphost 'modules/vmjumpbox.module.bicep' = {
  name: 'jumphost-deployment'
  params: {
    name: resourceNames.jumphostVirtualMachine
    location: location
    tags: tags
    adminPassword: jumphostAdministratorPassword
    dnsLabelPrefix: resourceNames.jumphostVirtualMachine
    subnetId: vnet.outputs.devOpsSnetId
    includeVsCode: false
  }
}

module applicationGateway 'modules/applicationGateway.module.bicep' = {
  name: 'applicationGateway-deployment'
  params: {
    name: resourceNames.applicationGateway
    location: location
    tags: tags
    dnsLabelPrefix: resourceNames.frontendWebApp
    frontendWebAppFqdn: frontendWebApp.outputs.siteHostName
    subnetId: vnet.outputs.defaultSnetId
  }
}

module bastion 'modules/bastion.module.bicep' = {
  name: 'bastion-deployment'
  params: {
    name: resourceNames.bastion
    location: location
    tags: tags
    subnetId: vnet.outputs.bastionSnetId
  }
}

output containerRegistry object = containerRegistry
output frontendWebApp object = frontendWebApp
output storageAccountName string = storage.outputs.name
output sqlServer object = sqlServer
output jumphost object = jumphost
