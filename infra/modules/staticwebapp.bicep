// Static Web App (Free) para el frontend Expo web. El contenido se sube aparte
// con la SWA CLI (`swa deploy`); aquí sólo se crea el recurso.
param name string
param location string
param tags object

resource swa 'Microsoft.Web/staticSites@2023-12-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Free'
    tier: 'Free'
  }
  properties: {}
}

output defaultHostname string = swa.properties.defaultHostname
output name string = swa.name
