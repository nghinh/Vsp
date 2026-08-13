# The API image.
#
# This lived only on the deploy host until now, which is why one `rsync
# --delete` of the source tree removed it and the next build failed with "open
# Dockerfile: no such file or directory". Reconstructed from the image's own
# layer history and the build log beside it, and kept here so the thing that
# builds the service is versioned with the service.
#
# Two stages, so the runtime image carries a JRE and a jar rather than Maven,
# a JDK and a populated ~/.m2 — which is roughly 600 MB of build tooling that
# a running service has no use for.

FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /build

# The pom alone first, so the dependency download is a cached layer that
# survives every source edit. `|| true` because go-offline reports failure for
# plugins it cannot fully resolve ahead of time, and the real build below
# fetches whatever is genuinely missing.
COPY pom.xml .
RUN mvn -B -q -Ddependency-check.skip=true dependency:go-offline || true

COPY dependency-check-suppressions.xml ./
COPY src ./src

# `lib/` is deliberately not copied. It holds one stray Dart file that the
# Maven build has no use for, and the original image did not copy it either.

# Tests run in CI and on a developer's machine, against a real Postgres. They
# are skipped here because this stage has no database to run them against, and
# a build that silently skips the tests it cannot run is better than one that
# passes them vacuously.
RUN mvn -B -q -DskipTests -Ddependency-check.skip=true clean package

FROM eclipse-temurin:21-jre-jammy
WORKDIR /app

# Not root. A Spring Boot service needs nothing root grants.
RUN groupadd -r vsp && useradd -r -g vsp vsp

# Where scorecard photographs land when VSP_SCORECARD_PHOTO_DIR points here.
# Created with an owner because the service does not run as root and could not
# otherwise create it; declared a VOLUME because a photograph written into the
# container's own filesystem is gone at the next rebuild, and losing the image
# a card was approved from is the failure this directory exists to prevent.
RUN mkdir -p /var/lib/vsp/scorecard-photos && chown -R vsp:vsp /var/lib/vsp
VOLUME ["/var/lib/vsp/scorecard-photos"]

COPY --from=build /build/target/*.jar /app/app.jar

USER vsp
EXPOSE 8080

# MaxRAMPercentage rather than a fixed -Xmx: the heap then follows whatever the
# container is actually given, so raising the compose memory limit raises the
# heap without a second edit here.
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "-jar", "/app/app.jar"]
