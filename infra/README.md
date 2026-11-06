# Infraestructura como código (Bicep)

Todo lo que la app necesita en Azure, en un solo grupo de recursos:

| Módulo | Recurso | SKU / notas |
|---|---|---|
| `observability.bicep` | Log Analytics `hp-logs-<sufijo>` | PerGB2018, 30 días, tope 1 GB/día |
| `registry.bicep` | ACR `hpacr<sufijo>` + identidad `hpacr<sufijo>-pull` con AcrPull | Basic, sin usuario admin |
| `postgres.bicep` | PostgreSQL Flexible `hp-pg-<sufijo>` + base `hotel_presidente` | B1ms, 32 GB, v16, extensiones que pide Flyway |
| `storage.bicep` | Storage `hpstore<sufijo>` + contenedor `uploads` | Standard_LRS, sin acceso público |
| `staticwebapp.bicep` | Static Web App `hp-web-<sufijo>` (frontend) | Free |
| `containerapp.bicep` | Entorno `hp-env-<sufijo>` + API `hp-api-<sufijo>` | Consumption, 0.5 vCPU / 1 Gi, réplicas 0–1 |

`main.bicep` los une y conecta la API con la base, Clerk y el origen de la
Static Web App (CORS, `azp`, liga de invitación y de autofacturación).

## Requisitos

- Azure CLI con Bicep (`az bicep install`).
- Los secretos como variables de entorno; `main.bicepparam` los lee con
  `readEnvironmentVariable`, así que nunca quedan en el repositorio:

| Variable | Obligatoria | Uso |
|---|---|---|
| `PG_PASS` | sí | contraseña del admin de PostgreSQL |
| `JWT_SECRET` | sí | `JWT_SECRET` de la API |
| `CLERK_SECRET_KEY` | no | administración del personal |
| `CLERK_WEBHOOK_SIGNING_SECRET` | no | webhook de Clerk |
| `SUF` | no (`aeffe7`) | sufijo de los nombres |
| `HP_API_IMAGE` | no (imagen de prueba de MCR) | imagen de la API |

## Uso

```bash
cd infra
set -a; source ~/hp-azure.env; set +a      # archivo local con las variables de abajo
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1   # sólo si falta libicu
az bicep build -f main.bicep                 # valida y compila a ARM

# Vista previa sin cambiar nada
az deployment group what-if -g rg-hotel-presidente -f main.bicep -p main.bicepparam

# Despliegue
az deployment group create -g rg-hotel-presidente -f main.bicep -p main.bicepparam
```

Primer despliegue en un grupo nuevo (la imagen todavía no existe en el ACR):

1. Desplegar con la imagen por omisión de MCR.
2. `az acr build -r hpacr<sufijo> -t hotel-presidente-api:<tag> ../api`
3. Volver a desplegar con `HP_API_IMAGE=hpacr<sufijo>.azurecr.io/hotel-presidente-api:<tag>`.
4. Subir el frontend con la URL de la API:
   `echo "window.API_URL='<apiUrl>'" > ../web/config.js` y
   `swa deploy ../web --env production --deployment-token $(az staticwebapp secrets list -n hp-web-<sufijo> --query properties.apiKey -o tsv)`.

## Regiones

La política de Azure for Students sólo permite `centralus`, `northcentralus`,
`canadacentral`, `westus3` y `mexicocentral`. Container Apps va en
`northcentralus` (parámetro `containerAppsLocation`) porque `centralus` dio
error de capacidad.
