# Multi-stage build for Scarlet (Linux headless)

# Stage 1: Build the shaded JAR with Maven
FROM maven:3.9.8-eclipse-temurin-8 AS build
WORKDIR /workspace
COPY pom.xml .
COPY src ./src
RUN mvn -B -DskipTests package

# Stage 2: Runtime image (Java 8 JRE)
FROM eclipse-temurin:8-jre

WORKDIR /app

# Copy artifact
COPY --from=build /workspace/target/scarlet-*.jar /app/scarlet.jar

# Runtime configuration
ENV SCARLET_HOME=/data \
    SCARLET_HEADLESS=true \
    JAVA_TOOL_OPTIONS="-Djava.awt.headless=true -XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap -XX:MaxRAMFraction=2"

# Pre-create data dir (volume will mount over it at runtime)
RUN mkdir -p /data
VOLUME ["/data"]

# Run as root (simplifies volume permissions in headless runtime)
ENTRYPOINT ["java","-jar","/app/scarlet.jar"]

