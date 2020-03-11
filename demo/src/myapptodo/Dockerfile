### BASE image - bare base image for our app with basic environment, JRE only
FROM openjdk:8-slim AS base   
RUN useradd --create-home -s /bin/bash user
WORKDIR /home/user
USER user
VOLUME /tmp
EXPOSE 8080
ENV APP_HOME /home/user/app
RUN mkdir $APP_HOME
RUN mkdir $APP_HOME/config

### BUILD image - image used to build app (full JDK)
FROM openjdk:8-jdk-alpine AS build
# Install Maven
RUN apk add --no-cache curl tar bash
ARG MAVEN_VERSION=3.3.9
ARG USER_HOME_DIR="/root"
RUN mkdir -p /usr/share/maven && \
curl -fsSL http://apache.osuosl.org/maven/maven-3/$MAVEN_VERSION/binaries/apache-maven-$MAVEN_VERSION-bin.tar.gz | tar -xzC /usr/share/maven --strip-components=1 && \
ln -s /usr/share/maven/bin/mvn /usr/bin/mvn
ENV MAVEN_HOME /usr/share/maven
ENV MAVEN_CONFIG "$USER_HOME_DIR/.m2"
# speed up Maven JVM a bit
ENV MAVEN_OPTS="-XX:+TieredCompilation -XX:TieredStopAtLevel=1"
ENTRYPOINT ["/usr/bin/mvn"]
# ----
# Install project dependencies and keep sources
# make source folder
RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app
# install maven dependency packages (keep in image)
COPY pom.xml /usr/src/app
COPY src /usr/src/app/src
# Build my applicatio
RUN mvn clean package

### CREATE final image - get compiled results and build final container from base (JRE only)
FROM base as final
USER user
WORKDIR $APP_HOME
COPY --chown=user:user --from=build /usr/src/app/target/app.jar .
# certificate for postgres
RUN mkdir /home/user/.postgresql
COPY --chown=user:user src/main/postgresql/root.crt /home/user/.postgresql/
# run it ...
ENTRYPOINT [ "java", "-Djava.security.egd=file:/dev/./urandom", "-Duser.home=/home/user", "-jar", "app.jar" ]
