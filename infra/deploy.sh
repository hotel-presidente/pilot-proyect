#!/usr/bin/env bash
# Despliegue completo: infraestructura (Bicep) + imagen de la API + frontend.
#
#   ./infra/deploy.sh <grupo-de-recursos> [region]
#
# Requiere en el entorno PG_PASS y JWT_SECRET (ver infra/README.md); el resto
# tiene valor por omisión. Crea el grupo si no existe.
set -euo pipefail

RG=${1:?uso: deploy.sh <grupo-de-recursos> [region]}
LOCATION=${2:-centralus}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TAG=${TAG:-$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || date +%s)}
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1   # Bicep CLI sin libicu

: "${PG_PASS:?falta PG_PASS}" "${JWT_SECRET:?falta JWT_SECRET}"

out() { az deployment group show -g "$RG" -n "$1" --query "properties.outputs.$2.value" -o tsv; }

echo "==> Grupo $RG ($LOCATION)"
az group create -n "$RG" -l "$LOCATION" -o none

echo "==> 1/4 Infraestructura"
az deployment group create -g "$RG" -n infra -f "$ROOT/infra/main.bicep" -p "$ROOT/infra/main.bicepparam" -o none
ACR=$(out infra acrLoginServer)

echo "==> 2/4 Imagen de la API ($ACR, tag $TAG)"
az acr build -r "${ACR%%.*}" -t "hotel-presidente-api:$TAG" "$ROOT/api" --no-logs -o none

echo "==> 3/4 API con la imagen nueva"
HP_API_IMAGE="$ACR/hotel-presidente-api:$TAG" \
  az deployment group create -g "$RG" -n infra -f "$ROOT/infra/main.bicep" -p "$ROOT/infra/main.bicepparam" -o none
API_URL=$(out infra apiUrl)
WEB_URL=$(out infra webUrl)

echo "==> 4/4 Frontend"
echo "window.API_URL='$API_URL';" > "$ROOT/web/config.js"
TOKEN=$(az staticwebapp secrets list -n "$(out infra staticWebAppName)" -g "$RG" --query properties.apiKey -o tsv)
npx --yes @azure/static-web-apps-cli@2.0.2 deploy "$ROOT/web" --env production --deployment-token "$TOKEN"

echo
echo "Web: $WEB_URL"
echo "API: $API_URL/actuator/health"
