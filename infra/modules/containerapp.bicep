// Entorno de Container Apps (Consumption) + la API Spring Boot con escala a cero.
param envName string
param appName string
param location string
param tags object
param logAnalyticsName string
param logAnalyticsResourceGroup string = resourceGroup().name

param image string
// Vacío = imagen pública (p. ej. la de prueba de MCR), sin credenciales de registro.
param registryServer string = ''
param pullIdentityId string

param minReplicas int = 0
param maxReplicas int = 1
param cpu string = '0.5'
param memory string = '1Gi'

@description('Variables de entorno no secretas: [{ name, value }].')
param env array
@description('Secretos de la app: { nombre-del-secreto: { envName, value } }. Los vacíos se omiten.')
@secure()
param secrets object

resource logs 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logAnalyticsName
  scope: resourceGroup(logAnalyticsResourceGroup)
}

resource managedEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: envName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logs.properties.customerId
        sharedKey: logs.listKeys().primarySharedKey
      }
    }
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
  }
}

var secretList = filter(items(secrets), s => !empty(s.value.value))

resource app 'Microsoft.App/containerApps@2024-03-01' = {
  name: appName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${pullIdentityId}': {} }
  }
  properties: {
    environmentId: managedEnv.id
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 8080
        transport: 'auto'
        allowInsecure: false
      }
      registries: empty(registryServer) ? [] : [
        {
          server: registryServer
          identity: pullIdentityId
        }
      ]
      secrets: [for s in secretList: {
        name: s.key
        // El valor viene del objeto @secure() `secrets`.
        #disable-next-line use-secure-value-for-secure-inputs
        value: s.value.value
      }]
    }
    template: {
      containers: [
        {
          name: 'api'
          image: image
          resources: {
            cpu: json(cpu)
            memory: memory
          }
          env: concat(env, map(secretList, s => {
            name: s.value.envName
            secretRef: s.key
          }))
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
        rules: [
          {
            name: 'http-scaler'
            http: { metadata: { concurrentRequests: '10' } }
          }
        ]
      }
    }
  }
}

output fqdn string = app.properties.configuration.ingress.fqdn
output name string = app.name
