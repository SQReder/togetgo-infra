#!/bin/sh
set -eu

cd /opt/ingress

marker=/opt/ingress/state/reload-required

/usr/bin/docker compose -f /opt/ingress/compose.yml run --rm certbot \
    renew --non-interactive \
    --deploy-hook 'touch /var/lib/ingress/reload-required'

if [ -e "$marker" ]; then
    /usr/bin/docker compose -f /opt/ingress/compose.yml exec -T nginx nginx -t
    /usr/bin/docker compose -f /opt/ingress/compose.yml exec -T nginx nginx -s reload
    rm -f "$marker"
fi
