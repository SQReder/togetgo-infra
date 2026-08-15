#!/bin/sh
# Sync ingress config to /opt/ingress and apply it. Run as root.
set -eu
cd "$(dirname "$0")"

if [ ! -f /opt/ingress/secrets/mtg.toml ]; then
    echo "missing /opt/ingress/secrets/mtg.toml — see secrets.example/mtg.toml" >&2
    exit 1
fi

install -d -m 750 /opt/ingress
rsync -r --delete --checksum nginx/ /opt/ingress/nginx/
rsync -r --checksum bin/ /opt/ingress/bin/
install -m 644 compose.yml /opt/ingress/compose.yml

docker compose -f /opt/ingress/compose.yml up -d --remove-orphans
docker compose -f /opt/ingress/compose.yml exec -T nginx nginx -t
docker compose -f /opt/ingress/compose.yml exec -T nginx nginx -s reload
docker compose -f /opt/ingress/compose.yml ps
