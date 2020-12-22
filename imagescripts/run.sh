#!/usr/bin/env bash

# DKIM
OPENDKIM_DIR="${OPENDKIM_DIR:-${ROOT_DIR}/opendkim}"
DKIM_LISTEN_ADDR="${DKIM_LISTEN_ADDR:-127.0.0.1}"
DKIM_LISTEN_PORT="${DKIM_LISTEN_PORT:-9901}"
DKIM_DOMAIN="${DKIM_DOMAIN:-${POSTFIX_DOMAIN}}"
DKIM_SELECTOR="${DKIM_SELECTOR:-mail}"
DKIM_KEY_FILE="${DKIM_KEY_FILE:-${OPENDKIM_DIR}/${DKIM_SELECTOR}.private}"
DKIM_TRUSTED_HOSTS="${DKIM_TRUSTED_HOSTS:-127.0.0.1\n::1\nlocalhost\n\n\*.example.com}"

# OpenDKIM config.

rm -rf /etc/opendkim
cat <<EOF > ${OPENDKIM_DIR}/opendkim.conf
# Basic
Background              false
BaseDirectory           ${OPENDKIM_DIR}

Syslog                  no
SyslogSuccess           yes
LogWhy                  yes
# Required to use local socket with MTAs that access the socket as a non-
# privileged user (e.g. Postfix)
UMask                   002

Mode                    sv
PidFile                 ${OPENDKIM_DIR}/opendkim.pid
UserID                  root:root
Socket                  inet:${DKIM_LISTEN_PORT}@${DKIM_LISTEN_ADDR}

Canonicalization        relaxed/simple
SignatureAlgorithm      rsa-sha256

# Sign for example.com with key in /etc/opendkim/mail.private using
# selector 'mail' (e.g. mail._domainkey.example.com)
Domain                  ${DKIM_DOMAIN}
KeyFile                 ${DKIM_KEY_FILE}
Selector                ${DKIM_SELECTOR}

ExternalIgnoreList      refile:${OPENDKIM_DIR}/TrustedHosts
InternalHosts           refile:${OPENDKIM_DIR}/TrustedHosts
EOF

# fill TrustedHosts
echo -e "${DKIM_TRUSTED_HOSTS}" > ${OPENDKIM_DIR}/TrustedHosts

# generate DKIM key/text
if [ ! -f "${DKIM_KEY_FILE}" ]; then
    cd "${OPENDKIM_DIR}"
    opendkim-genkey -s mail -d "${POSTFIX_DOMAIN}"
    chmod 600 mail.private
    cd -
    echo DKIM txt generated
fi
echo please consult your DNS service provider and add below to your DNS TXT record
cat ${OPENDKIM_DIR}/mail.txt

# start opendkim server
exec opendkim -x "${OPENDKIM_DIR}/opendkim.conf"
