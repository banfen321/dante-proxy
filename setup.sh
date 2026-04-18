#!/bin/sh
set -e

echo "============================================"
echo " Dante SOCKS5 Proxy — Initial Setup"
echo "============================================"
echo ""

printf "Port [1080]: "
read -r PORT
PORT="${PORT:-1080}"

printf "Username [proxy]: "
read -r USERNAME
USERNAME="${USERNAME:-proxy}"

printf "Password (leave empty to auto-generate): "
read -r PASSWORD
if [ -z "${PASSWORD}" ]; then
    PASSWORD=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 24)
    echo "Generated password: ${PASSWORD}"
fi

DEFAULT_IFACE=$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')
DEFAULT_IFACE="${DEFAULT_IFACE:-eth0}"
printf "External interface [%s]: " "${DEFAULT_IFACE}"
read -r IFACE
IFACE="${IFACE:-${DEFAULT_IFACE}}"

cat > .env << EOF
SOCKD_PORT=${PORT}
SOCKD_USER_NAME=${USERNAME}
SOCKD_USER_PASSWORD=${PASSWORD}
SOCKD_EXTERNAL_IFACE=${IFACE}
EOF

LOCAL_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '/src/ {for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' || echo "<your-host-ip>")

echo ""
echo "============================================"
echo " Config saved to .env"
echo "--------------------------------------------"
echo " Start with:  docker compose up -d"
echo "--------------------------------------------"
echo "   Host     : ${LOCAL_IP}"
echo "   Port     : ${PORT}"
echo "   User     : ${USERNAME}"
echo "   Password : ${PASSWORD}"
echo "============================================"
