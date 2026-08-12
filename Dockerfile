# Multi-stage build for Scarlet (Linux headless)

# Stage 1: Build the shaded JAR with Maven
FROM maven:3.9.8-eclipse-temurin-8 AS build
WORKDIR /workspace
COPY pom.xml .
COPY src ./src
# -Dnanohttpd.version overrides the pom's 2.3.2-SNAPSHOT. Those snapshots only
# ever lived on oss.sonatype.org, which has since been retired, so the build no
# longer resolves them from anywhere. This is not new to the upstream sync: the
# same deps are in 0.4.12-rc6, which means the previously deployed image could
# not be rebuilt from source either.
#
# They are test-scoped experiments (nanohttpd, jcef, selenium) that this image
# never runs, but -DskipTests does not help: Maven resolves the test classpath
# before the skip is evaluated. Overriding the property to a real released
# version satisfies resolution without patching the pom, which keeps the source
# tree identical to upstream.
RUN mvn -B -DskipTests -Dnanohttpd.version=2.3.1 package

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
# -XX:+UseCGroupMemoryLimitForHeap -XX:MaxRAMFraction=2, a cgroup-v1 only flag
# pair that a cgroup-v2 host ignores. The JVM says so itself on every start:
#   Unable to open cgroup memory limit file /sys/fs/cgroup/memory/memory.limit_in_bytes
# so MaxRAMFraction=2 fell through to physical RAM. Measured on the deployment
# host, that gave MaxHeapSize = 2055208960, i.e. ~1960 MB, half of a 3.9 GB box
# shared with other services.
#
# 1024m is a first bounded value, not a tuned one: there is no usage data for
# this app, so it is set generously to avoid trading an unbounded heap for a new
# OutOfMemoryError. Tune it with `docker stats scarlet` once it has run a while,
# and move it and the compose mem_limit together.
ENV SCARLET_HOME=/data \
    JAVA_TOOL_OPTIONS="-Djava.awt.headless=true -Xms256m -Xmx1024m"

# Pre-create data dir (volume will mount over it at runtime)
RUN mkdir -p /data
VOLUME ["/data"]

# Run as root (simplifies volume permissions in headless runtime)
ENTRYPOINT ["java","-jar","/app/scarlet.jar"]
