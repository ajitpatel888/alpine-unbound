#!/bin/sh
set -e

# Fetch the latest root hints using native wget
wget -qO /opt/unbound/etc/unbound/root.hints https://www.internic.net/domain/named.cache

# Update the DNSSEC root key (returns 1 on success, so we use || true)
/opt/unbound/sbin/unbound-anchor -a /opt/unbound/etc/unbound/root.key || true

# Enforce strict permissions before Unbound drops privileges
chown -R _unbound:_unbound /opt/unbound/etc/unbound

# Execute Unbound in the foreground
exec /opt/unbound/sbin/unbound -d -c /opt/unbound/etc/unbound/unbound.conf
