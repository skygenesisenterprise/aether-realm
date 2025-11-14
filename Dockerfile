# Multi-stage build for Keycloak application
FROM maven:3.9.8-openjdk-17 AS build

WORKDIR /app

# Copy pom files first for better Docker layer caching
COPY pom.xml .
COPY boms/pom.xml ./boms/
COPY common/pom.xml ./common/
COPY core/pom.xml ./core/
COPY crypto/pom.xml ./crypto/
COPY dependencies/pom.xml ./dependencies/
COPY model/pom.xml ./model/
COPY quarkus/pom.xml ./quarkus/
COPY rest/pom.xml ./rest/
COPY server-spi/pom.xml ./server-spi/
COPY server-spi-private/pom.xml ./server-spi-private/
COPY services/pom.xml ./services/
COPY saml-core-api/pom.xml ./saml-core-api/
COPY saml-core/pom.xml ./saml-core/
COPY themes/pom.xml ./themes/
COPY util/pom.xml ./util/

# Download dependencies
RUN mvn dependency:go-offline -B

# Copy source code
COPY . .

# Build the application
RUN mvn clean package -DskipTests -B

# Runtime stage
FROM openjdk:17-jre-slim

# Install required packages
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create application user
RUN groupadd -r keycloak && useradd -r -g keycloak keycloak

# Set working directory
WORKDIR /opt/keycloak

# Copy built application from build stage
COPY --from=build /app/quarkus/runtime/target/quarkus-app/ ./
COPY --from=build /app/distribution/server-dist/target/keycloak-999.0.0-SNAPSHOT/ ./server/

# Change ownership to keycloak user
RUN chown -R keycloak:keycloak /opt/keycloak

# Switch to non-root user
USER keycloak

# Expose ports
EXPOSE 8080 8443 9000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/health/ready || exit 1

# Environment variables
ENV JAVA_OPTS="-Xmx1024m -Xms512m"
ENV KC_HOSTNAME=localhost
ENV KC_HTTP_ENABLED=true

# Start Keycloak
ENTRYPOINT ["./server/bin/kc.sh", "start-dev"]