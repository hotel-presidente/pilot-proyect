// Infraestructura completa de Hotel Presidente en un grupo de recursos:
//   Log Analytics, ACR (+ identidad AcrPull), PostgreSQL Flexible, Storage,
//   Static Web App (frontend) y Container Apps (API con escala a cero).
//
// Despliegue:  az deployment group create -g <rg> -f main.bicep -p main.bicepparam
// Vista previa: az deployment group what-if -g <rg> -f main.bicep -p main.bicepparam
targetScope = 'resourceGroup'

@description('Región de casi todo (la política de Azure for Students sólo permite unas cuantas).')
@allowed(['centralus', 'northcentralus', 'canadacentral', 'westus3', 'mexicocentral'])
param location string = 'centralus'

@description('Región de Container Apps; centralus dio error de capacidad, por eso va aparte.')
@allowed(['centralus', 'northcentralus', 'canadacentral', 'westus3', 'mexicocentral'])
param containerAppsLocation string = 'northcentralus'

@description('Sufijo de los nombres globales (ACR, Storage, Postgres). El despliegue actual usa aeffe7.')
@minLength(3)
@maxLength(10)
param suffix string = substring(uniqueString(resourceGroup().id), 0, 6)

@description('Imagen de la API. Por omisión la de prueba de MCR, para poder crear todo antes del primer `az acr build`.')
param apiImage string = 'mcr.microsoft.com/k8se/quickstart:latest'

param postgresAdminLogin string = 'hpadmin'
@secure()
param postgresAdminPassword string
param databaseName string = 'hotel_presidente'

@secure()
@description('Firma de las ligas de autofacturación (>= 32 bytes).')
param jwtSecret string

@description('Frontend API URL de Clerk, sin "/" final.')
param clerkIssuer string
@secure()
param clerkSecretKey string = ''
@secure()
param clerkWebhookSigningSecret string = ''

@description('Orígenes extra del frontend además del de la Static Web App (separados por comas).')
param extraAllowedOrigins string = ''

param tags object = {
  app: 'hotel-presidente'
  managedBy: 'bicep'
}

module logs 'modules/observability.bicep' = {
  name: 'logs'
  params: {
    name: 'hp-logs-${suffix}'
    location: location
    tags: tags
  }
}

module registry 'modules/registry.bicep' = {
  name: 'registry'
  params: {
    name: 'hpacr${suffix}'
    location: location
    tags: tags
  }
}

module postgres 'modules/postgres.bicep' = {
  name: 'postgres'
  params: {
    name: 'hp-pg-${suffix}'
    location: location
    tags: tags
    adminLogin: postgresAdminLogin
    adminPassword: postgresAdminPassword
    databaseName: databaseName
  }
}

module storage 'modules/storage.bicep' = {
  name: 'storage'
  params: {
    name: 'hpstore${suffix}'
    location: location
    tags: tags
  }
}

module web 'modules/staticwebapp.bicep' = {
  name: 'web'
  params: {
    name: 'hp-web-${suffix}'
    location: location
    tags: tags
  }
}

var webOrigin = 'https://${web.outputs.defaultHostname}'
var allowedOrigins = empty(extraAllowedOrigins) ? webOrigin : '${webOrigin},${extraAllowedOrigins}'
// Las imágenes de MCR son públicas; sólo las del ACR propio necesitan credenciales.
var usesAcr = startsWith(apiImage, registry.outputs.loginServer)

module api 'modules/containerapp.bicep' = {
  name: 'api'
  params: {
    envName: 'hp-env-${suffix}'
    appName: 'hp-api-${suffix}'
    location: containerAppsLocation
    tags: tags
    logAnalyticsName: logs.outputs.name
    image: apiImage
    registryServer: usesAcr ? registry.outputs.loginServer : ''
    pullIdentityId: registry.outputs.pullIdentityId
    env: [
      { name: 'SPRING_PROFILES_ACTIVE', value: 'sandbox' }
      { name: 'DATABASE_URL', value: 'jdbc:postgresql://${postgres.outputs.fqdn}:5432/${postgres.outputs.databaseName}?sslmode=require' }
      { name: 'DATABASE_USERNAME', value: postgresAdminLogin }
      { name: 'CLERK_ISSUER', value: clerkIssuer }
      { name: 'CLERK_AUTHORIZED_PARTIES', value: allowedOrigins }
      { name: 'CLERK_INVITATION_REDIRECT_URL', value: '${webOrigin}/aceptar-invitacion' }
      { name: 'CORS_ALLOWED_ORIGINS', value: allowedOrigins }
      { name: 'CFDI_SELF_SERVICE_BASE_URL', value: webOrigin }
      { name: 'FORWARD_HEADERS_STRATEGY', value: 'framework' }
      { name: 'API_DOCS_ENABLED', value: 'true' }
    ]
    secrets: {
      'db-pass': { envName: 'DATABASE_PASSWORD', value: postgresAdminPassword }
      'jwt-secret': { envName: 'JWT_SECRET', value: jwtSecret }
      'clerk-sk': { envName: 'CLERK_SECRET_KEY', value: clerkSecretKey }
      'clerk-whsec': { envName: 'CLERK_WEBHOOK_SIGNING_SECRET', value: clerkWebhookSigningSecret }
    }
  }
}

output webUrl string = webOrigin
output apiUrl string = 'https://${api.outputs.fqdn}'
output acrLoginServer string = registry.outputs.loginServer
output postgresFqdn string = postgres.outputs.fqdn
output staticWebAppName string = web.outputs.name
output containerAppName string = api.outputs.name
