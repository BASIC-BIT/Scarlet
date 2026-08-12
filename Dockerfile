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

# Runtime configuration.
#
# JVM flags go in JAVA_TOOL_OPTIONS, not JAVA_OPTS: the ENTRYPOINT below is
# exec-form with no shell, so a $JAVA_OPTS reference would never expand. The JVM
# reads JAVA_TOOL_OPTIONS itself, which is why it works without one.
#
# -Djava.awt.headless=true is load-bearing. GraphicsEnvironment.isHeadless()
# selects ScarletUIHeadless over the Swing UI; without it the container gets the
# desktop code paths and dies on the first dialog.
#
# The heap is set explicitly rather than by percentage. It replaces
# -XX:+UseCGroupMemoryLimitForHeap -XX:MaxRAMFraction=2, which was a cgroup-v1
# only flag pair that any cgroup-v2 host silently ignored. 900m sits just under
# the compose mem_limit and roughly matches the default this container actually
# ran with before (a quarter of a 3.9 GB host), so it bounds the heap without
# shrinking it. Raise both together if the bot starts hitting OutOfMemoryError.
ENV SCARLET_HOME=/data \
    JAVA_TOOL_OPTIONS="-Djava.awt.headless=true -Xms256m -Xmx900m"

# Pre-create data dir (volume will mount over it at runtime)
RUN mkdir -p /data
VOLUME ["/data"]

# Run as root (simplifies volume permissions in headless runtime)
ENTRYPOINT ["java","-jar","/app/scarlet.jar"]
