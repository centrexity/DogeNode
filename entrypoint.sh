#!/bin/bash
set -euo pipefail

PUID="${PUID:-99}"
PGID="${PGID:-100}"

DOGE_PRUNE_MB="${DOGE_PRUNE_MB:-5500}"
DOGE_RPC_PORT="${DOGE_RPC_PORT:-22555}"
DOGE_P2P_PORT="${DOGE_P2P_PORT:-22556}"
DOGE_RPC_USER="${DOGE_RPC_USER:-simoleons}"
DOGE_TESTNET="${DOGE_TESTNET:-0}"

CONF="/config/dogecoin.conf"
RPC_ENV="/config/rpc.env"
TOKEN_FILE="/config/cloudflared/token"

groupmod -o -g "$PGID" dogecoin 2>/dev/null || true
usermod -o -u "$PUID" -g "$PGID" dogecoin 2>/dev/null || true

mkdir -p /dogecoin /config/cloudflared
chown -R dogecoin:dogecoin /dogecoin /config

if [ -z "${DOGE_RPC_PASSWORD:-}" ]; then
  if [ -f "$RPC_ENV" ]; then
    # shellcheck disable=SC1090
    source "$RPC_ENV"
  fi
fi

if [ -z "${DOGE_RPC_PASSWORD:-}" ]; then
  DOGE_RPC_PASSWORD=""
  while [ "${#DOGE_RPC_PASSWORD}" -lt 48 ]; do
    DOGE_RPC_PASSWORD="${DOGE_RPC_PASSWORD}$(head -c 96 /dev/urandom | tr -dc 'A-Za-z0-9' || true)"
  done
  DOGE_RPC_PASSWORD="${DOGE_RPC_PASSWORD:0:48}"

  {
    echo "DOGE_RPC_USER=${DOGE_RPC_USER}"
    echo "DOGE_RPC_PASSWORD=${DOGE_RPC_PASSWORD}"
  } > "$RPC_ENV"
  chmod 600 "$RPC_ENV"
fi

if [ "$DOGE_TESTNET" = "1" ] || [ "$DOGE_TESTNET" = "true" ]; then
  DOGE_CHAIN_LINE="testnet=1"
  DOGE_RPC_PORT="${DOGE_RPC_PORT:-44555}"
  DOGE_P2P_PORT="${DOGE_P2P_PORT:-44556}"
else
  DOGE_CHAIN_LINE=""
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
port=${DOGE_P2P_PORT}
listen=1
upnp=0
${DOGE_CHAIN_LINE}
EOF

  chown dogecoin:dogecoin "$CONF"
  chmod 600 "$CONF"
fi

if [ ! -f "$TOKEN_FILE" ]; then
  echo "Cloudflare tunnel token missing at $TOKEN_FILE"
  echo "Create the file from Unraid at:"
  echo "  /mnt/user/appdata/dogenode/main-config/cloudflared/token"
  echo "The node will still start, but cloudflared will restart until the token exists."
fi

exec /usr/bin/supervisord -n -c /etc/supervisord.conf
