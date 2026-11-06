// Parámetros del despliegue. Los secretos NO viven aquí: se leen de variables de
// entorno al compilar (mismos nombres que ~/hp-azure.env: `set -a; source ~/hp-azure.env; set +a`).
using 'main.bicep'

param suffix = readEnvironmentVariable('SUF', 'aeffe7')
param apiImage = readEnvironmentVariable('HP_API_IMAGE', 'mcr.microsoft.com/k8se/quickstart:latest')

param postgresAdminLogin = readEnvironmentVariable('PG_ADMIN', 'hpadmin')
param postgresAdminPassword = readEnvironmentVariable('PG_PASS')
param jwtSecret = readEnvironmentVariable('JWT_SECRET')

param clerkIssuer = readEnvironmentVariable('CLERK_ISSUER', 'https://example.clerk.accounts.dev')
param clerkSecretKey = readEnvironmentVariable('CLERK_SECRET_KEY', '')
param clerkWebhookSigningSecret = readEnvironmentVariable('CLERK_WEBHOOK_SIGNING_SECRET', '')
