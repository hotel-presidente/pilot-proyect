# Hotel Presidente — proyecto piloto

Boilerplate del sistema Hotel Presidente para probar la infraestructura como
código (Bicep) en Azure. No tiene funcionalidad de negocio: sólo lo mínimo
para compilar, empaquetar, desplegar y comprobar que cada pieza responde.

```
infra/   Bicep: toda la infraestructura de Azure + deploy.sh
api/     API Spring Boot 4 (Java 25) con /actuator/health (comprueba PostgreSQL)
web/     Frontend estático que consulta la salud de la API
```

## Arquitectura en Azure

| Pieza | Recurso |
|---|---|
| Frontend | Static Web App (Free) |
| API | Container Apps (Consumption, escala a cero) |
| Imágenes | Container Registry (Basic) + identidad administrada con AcrPull |
| Base de datos | PostgreSQL Flexible Server 16 (B1ms) |
| Archivos | Storage Account (contenedor `uploads`) |
| Logs | Log Analytics |

El detalle de cada módulo está en [`infra/README.md`](infra/README.md).

## Despliegue

Requisitos: Azure CLI con sesión iniciada (`az login`), Bicep (`az bicep install`) y Node.js (para la SWA CLI).

```bash
export PG_PASS='<contraseña-de-postgres>'
export JWT_SECRET="$(openssl rand -hex 48)"
export SUF=demo01            # sufijo único para los nombres globales

./infra/deploy.sh rg-hotel-presidente-pilot
```

El script crea el grupo, despliega el Bicep, construye la imagen de la API en
el ACR (`az acr build`, sin Docker local), actualiza la Container App y sube el
frontend. Al final imprime las URLs de la web y de `/actuator/health`.

Vista previa sin cambiar nada:

```bash
az deployment group what-if -g <grupo> -f infra/main.bicep -p infra/main.bicepparam
```

Borrar todo:

```bash
az group delete -n rg-hotel-presidente-pilot --yes
```

## Local

```bash
cd api
./mvnw spring-boot:run       # necesita un PostgreSQL en localhost:5432
curl localhost:8080/actuator/health
```
