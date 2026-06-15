#!/bin/sh
set -eu

NGINX_CONFIG=/etc/nginx/conf.d/default.conf

if [ -z "${NGROK_AUTHTOKEN:-}" ]; then
  echo "dollhouse: NGROK_AUTHTOKEN is required" >&2
  exit 1
fi

validate_path() {
  case "$1" in
    ""|*/*|*:*|*[!abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-]*)
      echo "dollhouse: route path must be one top-level segment using A-Z, a-z, 0-9, _ or -: $1" >&2
      exit 1
      ;;
  esac
}

validate_host() {
  case "$1" in
    ""|*:*|*/*|*[!abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-]*)
      echo "dollhouse: route hostname must use A-Z, a-z, 0-9, _, . or -: $1" >&2
      exit 1
      ;;
  esac
}

validate_port() {
  case "$1" in
    ""|*[!0-9]*)
      echo "dollhouse: route port must be numeric: $1" >&2
      exit 1
      ;;
  esac
}

generate_nginx_config() {
  routes=$(printf '%s' "${DOLLHOUSE_ROUTES:-}" | tr ',' ' ')

  if [ -z "$routes" ]; then
    return 0
  fi

  cat > "$NGINX_CONFIG" <<'CONFIG'
server {
  listen 80;

  location = / {
    return 200 "dollhouse is running\n";
    add_header Content-Type text/plain;
  }
CONFIG

  for route in $routes; do
    old_ifs=$IFS
    IFS=:
    # shellcheck disable=SC2086
    set -- $route
    IFS=$old_ifs

    case $# in
      1)
        path=$1
        host=$1
        port=${DOLLHOUSE_DEFAULT_PORT:-80}
        ;;
      3)
        path=$1
        host=$2
        port=$3
        ;;
      *)
        echo "dollhouse: routes must be either path or path:hostname:port: $route" >&2
        exit 1
        ;;
    esac

    validate_path "$path"
    validate_host "$host"
    validate_port "$port"

    cat >> "$NGINX_CONFIG" <<CONFIG

  location = /$path {
    return 308 /$path/;
  }

  location ^~ /$path/ {
    proxy_http_version 1.1;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-Prefix /$path;
    proxy_pass http://$host:$port/;
  }
CONFIG
  done

  cat >> "$NGINX_CONFIG" <<'CONFIG'
}
CONFIG
}

generate_nginx_config
nginx -t

nginx -g 'daemon off;' &
nginx_pid="$!"
ngrok_pid=""

cleanup() {
  trap - INT TERM EXIT

  if [ -n "$ngrok_pid" ] && kill -0 "$ngrok_pid" 2>/dev/null; then
    kill "$ngrok_pid" 2>/dev/null || true
  fi

  if kill -0 "$nginx_pid" 2>/dev/null; then
    kill "$nginx_pid" 2>/dev/null || true
  fi

  wait 2>/dev/null || true
}

trap cleanup INT TERM EXIT

ngrok "$@" &
ngrok_pid="$!"

while :; do
  if ! kill -0 "$nginx_pid" 2>/dev/null; then
    wait "$nginx_pid"
    exit "$?"
  fi

  if ! kill -0 "$ngrok_pid" 2>/dev/null; then
    wait "$ngrok_pid"
    exit "$?"
  fi

  sleep 1
done
