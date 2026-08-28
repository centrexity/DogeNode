#!/bin/bash
set -euo pipefail

PUID="${PUID:-99}"
PGID="${PGID:-100}"
DOGE_PRUNE_MB="${DOGE_PRUNE_MB:-5500}"
DOGE_RPC_PORT="${DOGE_RPC_PORT:-22555}"
DOGE_RPC_USER="${DOGE_RPC_USER:-simoleons}"
CONF="/config/dogecoin.conf"

groupmod -o -g "$PGID" dogecoin 2>/dev/null || true
usermod -o -u "$PUID" -g "$PGID" dogecoin 2>/dev/null || true

mkdir -p /dogecoin /config/cloudflared
chown -R dogecoin:dogecoin /dogecoin /config

if [ -z "${DOGE_RPC_PASSWORD:-}" ]; then
  if [ -f /config/rpc.env ]; then
    source /config/rpc.env
  else
    DOGE_RPC_PASSWORD="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 48)"
    {
      echo "DOGE_RPC_USER=${DOGE_RPC_USER}"
      echo "DOGE_RPC_PASSWORD=${DOGE_RPC_PASSWORD}"
    } > /config/rpc.env
    chmod 600 /config/rpc.env
  fi
fi

if [ ! -f "$CONF" ]; then
  cat > "$CONF" <<EOF
server=1
daemon=0
printtoconsole=1
txindex=0
prune=${DOGE_PRUNE_MB}
rpcbind=127.0.0.1
rpcallowip=127.0.0.1
rpcport=${DOGE_RPC_PORT}
rpcuser=${DOGE_RPC_USER}
rpcpassword=${DOGE_RPC_PASSWORD}
listen=1
upnp=0
EOF
  chown dogecoin:dogecoin "$CONF"
  chmod 600 "$CONF"
fi

exec /usr/bin/supervisord -n -c /etc/supervisord.conf
