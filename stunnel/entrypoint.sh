#!/bin/sh
set -eu

STUNNEL_PORT="${STUNNEL_PORT:-1080}"
SOCKD_PORT="${SOCKD_PORT:-1081}"
CERT_DIR="/etc/stunnel/certs"

mkdir -p "${CERT_DIR}"

if [ ! -f "${CERT_DIR}/server.pem" ]; then
    echo "INFO: Generating self-signed TLS certificate..."
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
        -keyout "${CERT_DIR}/server.key" \
        -out    "${CERT_DIR}/server.pem" \
        -subj   "/CN=socks5-proxy" \
        2>/dev/null
    echo "INFO: Certificate generated. Mount a volume at ${CERT_DIR} to persist it,"
    echo "      or provide your own server.pem / server.key."
fi

sed \
    -e "s|STUNNEL_PORT|${STUNNEL_PORT}|g" \
    -e "s|SOCKD_PORT|${SOCKD_PORT}|g" \
    /etc/stunnel/stunnel.conf.tmpl > /etc/stunnel/stunnel.conf

echo "============================================"
echo " stunnel TLS wrapper"
echo "--------------------------------------------"
echo " Listen (TLS) : 0.0.0.0:${STUNNEL_PORT}"
echo " Forward to   : 127.0.0.1:${SOCKD_PORT}"
echo "============================================"

exec stunnel /etc/stunnel/stunnel.conf
