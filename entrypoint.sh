#!/bin/sh
set -eu

if [ -z "${SOCKD_EXTERNAL_IFACE:-}" ]; then
    SOCKD_EXTERNAL_IFACE=$(ip route show default | awk '/default/ {print $5; exit}')
    if [ -z "${SOCKD_EXTERNAL_IFACE:-}" ]; then
        echo "ERROR: Cannot auto-detect network interface." >&2
        echo "       Set SOCKD_EXTERNAL_IFACE=<interface> manually (e.g. eth0, ens3)." >&2
        exit 1
    fi
    echo "INFO: Auto-detected interface: ${SOCKD_EXTERNAL_IFACE}"
fi

SOCKD_PORT="${SOCKD_PORT:-1080}"
SOCKD_USER_NAME="${SOCKD_USER_NAME:-proxy}"

_creds_generated=0
if [ -z "${SOCKD_USER_PASSWORD:-}" ]; then
    SOCKD_USER_PASSWORD=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 24)
    _creds_generated=1
fi

id "${SOCKD_USER_NAME}" >/dev/null 2>&1 || \
    adduser -H -D -s /sbin/nologin "${SOCKD_USER_NAME}"
printf '%s:%s\n' "${SOCKD_USER_NAME}" "${SOCKD_USER_PASSWORD}" | chpasswd

sed \
    -e "s|SOCKD_PORT|${SOCKD_PORT}|g" \
    -e "s|SOCKD_EXTERNAL_IFACE|${SOCKD_EXTERNAL_IFACE}|g" \
    /etc/sockd.conf.tmpl > /etc/sockd.conf

echo "============================================"
echo " Dante SOCKS5 Proxy"
echo "--------------------------------------------"
echo " Interface : ${SOCKD_EXTERNAL_IFACE}"
echo " Port      : ${SOCKD_PORT}"
echo " User      : ${SOCKD_USER_NAME}"
if [ "${_creds_generated}" = "1" ]; then
    echo " Password  : ${SOCKD_USER_PASSWORD}"
    echo ""
    echo " NOTE: Password was auto-generated."
    echo "       Set SOCKD_USER_PASSWORD in .env"
    echo "       to keep it across restarts."
fi
echo "============================================"

exec sockd -f /etc/sockd.conf
