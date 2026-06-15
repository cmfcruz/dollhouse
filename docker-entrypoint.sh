#!/bin/sh
set -eu

NGINX_CONFIG=/etc/nginx/conf.d/default.conf

if [ -z "${NGROK_AUTHTOKEN:-}" ]; then
  echo "dollhouse: NGROK_AUTHTOKEN is required" >&2
  exit 1
fi

# Reject values with characters outside the allowed set, so route data can't
# break out of the generated nginx config. Args: label, value, allowed chars.
validate() {
  case "$2" in
    ""|*[!$3]*)
      echo "dollhouse: $1 must use only [$3]: '$2'" >&2
      exit 1
      ;;
  esac
}

# Build a reverse-proxy config from DOLLHOUSE_ROUTES, a comma-separated list of
# "path" or "path:hostname:port" entries (port defaults to DOLLHOUSE_DEFAULT_PORT).
generate_nginx_config() {
  routes=$(printf '%s' "${DOLLHOUSE_ROUTES:-}" | tr ',' ' ')
  [ -n "$routes" ] || return 0

  cat > "$NGINX_CONFIG" <<'CONFIG'
server {
  listen 80;

  location = / {
    return 200 "dollhouse is running\n";
    add_header Content-Type text/plain;
  }
CONFIG

  for route in $routes; do
    old_ifs=$IFS; IFS=:
    # shellcheck disable=SC2086
    set -- $route
    IFS=$old_ifs

    case $# in
      1) path=$1 host=$1 port=${DOLLHOUSE_DEFAULT_PORT:-80} ;;
      3) path=$1 host=$2 port=$3 ;;
      *) echo "dollhouse: route must be 'path' or 'path:hostname:port': $route" >&2; exit 1 ;;
    esac

    validate "route path" "$path" '[:alnum:]_-'
    validate "route hostname" "$host" '[:alnum:]_.-'
    validate "route port" "$port" '0-9'

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

  echo '}' >> "$NGINX_CONFIG"
}

generate_nginx_config
nginx -t

nginx -g 'daemon off;' & nginx_pid=$!
ngrok "$@" & ngrok_pid=$!

# Stop both processes whenever this script exits.
trap 'kill "$nginx_pid" "$ngrok_pid" 2>/dev/null || true' INT TERM EXIT

# Block until either process exits, then reap it so its status becomes ours
# (the trap stops the other).
while kill -0 "$nginx_pid" 2>/dev/null && kill -0 "$ngrok_pid" 2>/dev/null; do
  sleep 1
done

if kill -0 "$nginx_pid" 2>/dev/null; then
  wait "$ngrok_pid"
else
  wait "$nginx_pid"
fi
