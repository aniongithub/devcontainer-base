# Build our custom version of docker-machine because of this issue
# https://github.com/docker/machine/pull/4790

# Also, ensure we build on Alpine because we want a libmusl
# dependency, not a glibc one:
# https://stackoverflow.com/a/52057474/802203
FROM golang:1.13-alpine AS docker-machine-builder

RUN apk add git \
            make &&\
    go get golang.org/x/lint/golint \
           github.com/mattn/goveralls \
           golang.org/x/tools/cover

WORKDIR /go/src/github.com/docker/machine
RUN cd /go/src/github.com/docker &&\
    git clone https://github.com/aniongithub/machine.git &&\
    cd machine &&\
    make build &&\
    make install

# Our main stage
FROM alpine

RUN apk update &&\
    apk add \
        jq \
        vde2 &&\
    rm -rf /var/cache/apk/*

# Install docker client
ARG DOCKER_CLI_VERSION="19.03.8"
ENV DOWNLOAD_URL="https://download.docker.com/linux/static/stable/x86_64/docker-$DOCKER_CLI_VERSION.tgz"

RUN apk --update add \
       curl \
    && mkdir -p /tmp/download \
    && curl -L $DOWNLOAD_URL | tar -xz -C /tmp/download \
    && mv /tmp/download/docker/docker /usr/local/bin/ \
    && rm -rf /tmp/download \
    && rm -rf /var/cache/apk/*

# Make sh (not ash) the default shell for all users
RUN sed -i -e 's/\/ash/\/sh/g' /etc/passwd

# Set PS1 to show a usable prompt
ENV PS1='$(whoami)@$(hostname):$(pwd)$ '

# Install docker-machine from custom build
WORKDIR /usr/local/bin
COPY --from=docker-machine-builder /go/src/github.com/docker/machine/bin/docker-machine /usr/local/bin

# Copy all templates
WORKDIR /templates
COPY . /templates

ENTRYPOINT [ "/bin/sh" ]