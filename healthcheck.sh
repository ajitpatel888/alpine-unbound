#!/bin/sh
set -e

HEALTHCHECK_PORT=${HEALTHCHECK_PORT:-5335}
EXTENDED_HEALTHCHECK_DOMAIN=${EXTENDED_HEALTHCHECK_DOMAIN:-cloudflare.com}

# Verify Unbound is listening on the port
check_port="$(netstat -ln | grep -c ":$HEALTHCHECK_PORT")" || true
if [ "$check_port" -eq 0 ]; then
  echo "Port $HEALTHCHECK_PORT not open"
  exit 1
fi

# Execute DNS resolution check via ldns
drill -p "$HEALTHCHECK_PORT" "$EXTENDED_HEALTHCHECK_DOMAIN" @127.0.0.1 > /dev/null
if [ $? -ne 0 ]; then
  echo "Domain '$EXTENDED_HEALTHCHECK_DOMAIN' not resolved"
  exit 1 
fi

echo "Healthcheck passed"
exit 0
