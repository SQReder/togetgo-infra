#!/bin/sh
# First-time setup on a fresh server. Run as root after installing docker
# with the compose plugin. Safe to re-run: every step is idempotent.
#
# Certificate chicken-and-egg: https vhosts reference letsencrypt paths that
# do not exist yet, so the first start runs without conf.d/https.conf,
# certificates are issued over the ACME webroot on port 80, and only then
# the full config is deployed.
set -eu
cd "$(dirname "$0")"

ACME_EMAIL=sqreder@gmail.com
DOMAINS="web.togetgo.app admin.togetgo.app s3.togetgo.app"

install -d -m 750 /opt/ingress /opt/ingress/state /opt/ingress/letsencrypt /opt/ingress/secrets

if [ ! -f /opt/ingress/secrets/mtg.toml ]; then
    install -m 600 secrets.example/mtg.toml /opt/ingress/secrets/mtg.toml
    mtg_secret=$(docker run --rm nineseconds/mtg:2 generate-secret storage.googleapis.com)
    sed -i "s/REPLACE_ME/$mtg_secret/" /opt/ingress/secrets/mtg.toml
fi
install -d -m 755 /opt/ingress/certbot/www
docker network inspect togetgo-public >/dev/null 2>&1 || docker network create togetgo-public

if [ ! -d /opt/ingress/letsencrypt/live ]; then
    install -d -m 750 /opt/ingress/nginx/conf.d
    rsync -r --checksum --exclude 'conf.d/https*' nginx/ /opt/ingress/nginx/
    install -m 644 compose.yml /opt/ingress/compose.yml
    docker compose -f /opt/ingress/compose.yml up -d nginx
    for domain in $DOMAINS; do
        docker compose -f /opt/ingress/compose.yml run --rm certbot \
            certonly --webroot -w /var/www/certbot -d "$domain" \
            --non-interactive --agree-tos -m "$ACME_EMAIL"
    done
fi

./deploy.sh
