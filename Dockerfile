# Build our custom version of docker-machine because of this issue
# https://github.com/docker/machine/pull/4790
FROM golang:1.12.9 AS docker-machine-builder

RUN go get  golang.org/x/lint/golint \
            github.com/mattn/goveralls \
            golang.org/x/tools/cover

WORKDIR /go/src/github.com/docker/machine
RUN cd /go/src/github.com/docker &&\
    git clone https://github.com/aniongithub/machine.git &&\
    cd machine &&\
    make build

# Our main stage
FROM alpine

RUN apk update &&\
    apk add \
        jq \
        vde2 &&\
    rm -rf /var/cache/apk/*

ARG DOCKER_CLI_VERSION="19.03.8"
ENV DOWNLOAD_URL="https://download.docker.com/linux/static/stable/x86_64/docker-$DOCKER_CLI_VERSION.tgz"

# Install docker client
RUN apk --update add curl \
    && mkdir -p /tmp/download \
    && curl -L $DOWNLOAD_URL | tar -xz -C /tmp/download \
    && mv /tmp/download/docker/docker /usr/local/bin/ \
    && rm -rf /tmp/download \
    && apk del curl \
    && rm -rf /var/cache/apk/*

# Make sh (not ash) the default shell for all users
RUN sed -i -e 's/\/ash/\/sh/g' /etc/passwd

# Set PS1 to show a usable prompt
ENV PS1='$(whoami)@$(hostname):$(pwd)$ '

# Install docker-machine from custom build
COPY --from=docker-machine-builder /go/src/github.com/docker/machine/bin/docker-machine /usr/local/bin

# Copy all templates
WORKDIR /templates
COPY . /templates

ENTRYPOINT [ "/bin/sh" ]