#!/usr/bin/env bash

# DKIM
OPENDKIM_DIR="${OPENDKIM_DIR:-${ROOT_DIR}/opendkim}"
DKIM_LISTEN_ADDR="${DKIM_LISTEN_ADDR:-127.0.0.1}"
DKIM_LISTEN_PORT="${DKIM_LISTEN_PORT:-9901}"
DKIM_DOMAINS="${DKIM_DOMAINS}"
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
KeyTable                ${OPENDKIM_DIR}/KeyTable
SigningTable            ${OPENDKIM_DIR}/SigningTable

ExternalIgnoreList      refile:${OPENDKIM_DIR}/TrustedHosts
InternalHosts           refile:${OPENDKIM_DIR}/TrustedHosts
EOF

# generate DKIM keys
rm -rf "${OPENDKIM_DIR}/KeyTable"
rm -rf "${OPENDKIM_DIR}/SigningTable"
pushd "${OPENDKIM_DIR}"
mkdir -p "keys"

IFS=' ' read -ra items <<< "${DKIM_DOMAINS}"
for i in "${items[@]}"; do
    if [ ! -f "./keys/${DKIM_SELECTOR}.${i}.private" ]; then
        pushd keys
        opendkim-genkey -s "${DKIM_SELECTOR}" -d "${i}"
        chmod 600 "${DKIM_SELECTOR}".private
        mv "${DKIM_SELECTOR}".private "${DKIM_SELECTOR}.${i}".private
        mv "${DKIM_SELECTOR}".txt "${DKIM_SELECTOR}.${i}".txt
        popd
    fi
    echo :::please consult your DNS service provider and add below to your DNS TXT record:::
    cat "./keys/${DKIM_SELECTOR}.${i}".txt

    cat <<EOF >> KeyTable
${DKIM_SELECTOR}._domainkey.${i} ${i}:${DKIM_SELECTOR}:${OPENDKIM_DIR}/keys/${DKIM_SELECTOR}.${i}.private
EOF

    cat <<EOF >> SigningTable
${i} ${DKIM_SELECTOR}._domainkey.${i}
EOF
done
popd

# fill TrustedHosts
echo -e "${DKIM_TRUSTED_HOSTS}" > ${OPENDKIM_DIR}/TrustedHosts

# start opendkim server
exec opendkim -x "${OPENDKIM_DIR}/opendkim.conf"
