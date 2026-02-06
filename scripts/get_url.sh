#!/bin/bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
load_env

rawurlencode() {
  local s="${1:-}"
  local out=""
  local i c
  for ((i=0; i<${#s}; i++)); do
    c="${s:i:1}"
    case "$c" in
      [a-zA-Z0-9.~_-]) out+="$c" ;;
      *) printf -v out '%s%%%02X' "$out" "'$c" ;;
    esac
  done
  printf '%s' "$out"
}

SSL_MODE="${SSL_MODE:-disable}"

PASS_ENC="$(rawurlencode "${DB_PASSWORD:-}")"
USER_ENC="$(rawurlencode "${DB_USER:-}")"
DB_ENC="$(rawurlencode "${DB_NAME:-}")"

BASE_HOSTPORT="${DB_HOST_IP}:${DB_PORT_EXTERNAL}"
BASE_PATH="/${DB_ENC}"
BASE_QUERY="sslmode=${SSL_MODE}"

URL_SQLALCHEMY_ASYNCPG="postgresql+asyncpg://${USER_ENC}:${PASS_ENC}@${BASE_HOSTPORT}${BASE_PATH}?${BASE_QUERY}"
URL_ASYNCPG="postgresql://${USER_ENC}:${PASS_ENC}@${BASE_HOSTPORT}${BASE_PATH}?${BASE_QUERY}"

echo "SQLAlchemy (asyncpg):"
echo "$URL_SQLALCHEMY_ASYNCPG"
echo
echo "asyncpg (raw):"
echo "$URL_ASYNCPG"
