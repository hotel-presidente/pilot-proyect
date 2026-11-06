// Log Analytics: destino de los logs de Container Apps.
param name string
param location string
param tags object

resource logs 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
    // Tope diario para no sorprender a la suscripción de estudiante.
    workspaceCapping: { dailyQuotaGb: 1 }
  }
}

output id string = logs.id
output name string = logs.name
