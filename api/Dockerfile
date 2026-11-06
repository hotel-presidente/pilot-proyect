# syntax=docker/dockerfile:1
# Imagen de la API. Compila dentro del contenedor con JDK 25; en Azure se
# construye con `az acr build` (ver infra/README.md).

FROM docker.io/library/eclipse-temurin:25-jdk-alpine AS build
WORKDIR /src

COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
RUN sh ./mvnw --batch-mode --no-transfer-progress dependency:go-offline

COPY src/ src/
RUN sh ./mvnw --batch-mode --no-transfer-progress package \
 && cp target/pilot-api-*.jar /src/app.jar

FROM docker.io/library/eclipse-temurin:25-jre-alpine
WORKDIR /app
RUN addgroup -S app && adduser -S -G app app
COPY --from=build /src/app.jar app.jar
USER app
EXPOSE 8080
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-jar", "/app/app.jar"]
