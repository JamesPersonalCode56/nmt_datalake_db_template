#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
COMPOSE_FILE="$ROOT_DIR/docker-compose.yml"

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

load_env() {
  if [ ! -f "$ENV_FILE" ]; then
    echo "Error: .env file not found at $ENV_FILE"
    exit 1
  fi
  while IFS= read -r raw_line || [ -n "$raw_line" ]; do
    local line key value
    line="${raw_line%$'\r'}"
    line="$(trim "$line")"
    [ -z "$line" ] && continue
    [[ "$line" == \#* ]] && continue
    if [[ "$line" != *=* ]]; then
      echo "Error: invalid .env line: $line"
      exit 1
    fi
    key="$(trim "${line%%=*}")"
    value="${line#*=}"
    value="$(trim "$value")"
    if [[ "$value" == \"*\" && "$value" == *\" ]]; then
      value="${value:1:${#value}-2}"
    elif [[ "$value" == \'*\' && "$value" == *\' ]]; then
      value="${value:1:${#value}-2}"
    else
      value="${value%% \#*}"
      value="$(trim "$value")"
    fi
    if ! [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      echo "Error: invalid env key: $key"
      exit 1
    fi
    export "$key=$value"
  done < "$ENV_FILE"
}

require_compose() {
  if [ ! -f "$COMPOSE_FILE" ]; then
    echo "Error: docker-compose.yml not found at $COMPOSE_FILE"
    exit 1
  fi
}

remove_dir_contents() {
  local dir="$1"
  [ -d "$dir" ] || return 0
  local entries=()
  shopt -s dotglob nullglob
  entries=("$dir"/*)
  shopt -u dotglob nullglob
  [ ${#entries[@]} -eq 0 ] && return 0
  if rm -rf -- "${entries[@]}" 2>/dev/null; then
    return 0
  fi
  if command -v sudo >/dev/null 2>&1; then
    sudo rm -rf -- "${entries[@]}"
    return $?
  fi
  echo "Error: cannot clear $dir. Run with a user that owns files or install sudo."
  return 1
}

remove_dir() {
  local dir="$1"
  [ -e "$dir" ] || return 0
  if rm -rf -- "$dir" 2>/dev/null; then
    return 0
  fi
  if command -v sudo >/dev/null 2>&1; then
    sudo rm -rf -- "$dir"
    return $?
  fi
  echo "Error: cannot remove $dir. Run with a user that owns files or install sudo."
  return 1
}
