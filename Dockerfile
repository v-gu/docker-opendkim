## -*- docker-image-name: lisnaz/opendkim -*-
#
# Dockerfile for opendkim
#
# need init: false
# dkim key will be generated inside ${OPENDKIM_DIR}

FROM lisnaz/alpine:latest
MAINTAINER Vincent Gu <v@vgu.io>

# variable list
# DKIM
ENV OPENDKIM_DIR                        "${ROOT_DIR}/opendkim"
ENV DKIM_LISTEN_ADDR                    "0.0.0.0"
ENV DKIM_LISTEN_PORT                    9901
ENV DKIM_DOMAINS                        ""
ENV DKIM_SELECTOR                       mail
ENV DKIM_KEY_FILE                       "${OPENDKIM_DIR}/${DKIM_SELECTOR}.private"
ENV DKIM_TRUSTED_HOSTS                  "127.0.0.1\n::1\nlocalhost\n\n\*.example.com"

# define service ports
EXPOSE $DKIM_LISTEN_PORT/tcp

# install software stack
RUN set -ex && \
    DEP='opendkim opendkim-utils' && \
    apk add --update --no-cache $DEP && \
    rm -rf /var/cache/apk/*

VOLUME "${OPENDKIM_DIR}"
