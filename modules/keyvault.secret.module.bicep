@description('Required. The Key Vault\'s name')
param keyVaultName string

@description('Required. The name of the secret in Key Vault.')
param name string

@secure()
param value string = ''

param serviceMetadata object

var deploy = (!empty(value) || !empty(serviceMetadata))
var secretValue = !empty(value) ? {
  value: value
} : serviceMetadata.type == 'storageAccount' ? {
  /* Storage Account */
  value: 'DefaultEndpointsProtocol=https;AccountName=${serviceMetadata.name};AccountKey=${listKeys(serviceMetadata.id, serviceMetadata.apiVersion).keys[0].value}'
} : serviceMetadata.type == 'redisCache' ? {
  /* Redis Cache */
  value: '${serviceMetadata.name}.redis.cache.windows.net,abortConnect=false,ssl=true,password=${listKeys(serviceMetadata.id, serviceMetadata.apiVersion).primaryKey}'
} : serviceMetadata.type == 'serviceBus' ? {
  /* Service Bus */
  value: listKeys(resourceId('Microsoft.ServiceBus/namespaces/authorizationRules', serviceMetadata.name, serviceMetadata.sasKeyName), serviceMetadata.apiVersion).primaryConnectionString
} : serviceMetadata.type == 'containerRegistry' ? {
  /* Container Registry */
  value: serviceMetadata.secretType == 'password' ? listCredentials(resourceId('Microsoft.ContainerRegistry/registries', serviceMetadata.name), serviceMetadata.apiVersion).passwords[0].value : listCredentials(resourceId('Microsoft.ContainerRegistry/registries', serviceMetadata.name), serviceMetadata.apiVersion).username
} : { 
  /* Unhandled type */
  value: '[[serviceMetadata.type "${serviceMetadata.type}" was unknown]]'
}

resource keyVaultSecret 'Microsoft.KeyVault/vaults/secrets@2018-02-14' = if (deploy) {
  name: '${keyVaultName}/${name}'
  properties: {
    value: secretValue.value
  }
}

output id string = keyVaultSecret.id
output name string = name
output type string = keyVaultSecret.type
output props object = keyVaultSecret.properties
output reference string = '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${name})'
