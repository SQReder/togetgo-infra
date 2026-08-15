#!/bin/sh
# Показывает расхождения /opt/ingress с репозиторием, ничего не меняя.
# Run as root. Выход 0 — дрифта нет, 1 — есть (список в stdout).
set -eu
cd "$(dirname "$0")"

rc=0
if rsync -rin --checksum --delete nginx/ /opt/ingress/nginx/ | grep .; then rc=1; fi
if rsync -rin --checksum bin/ /opt/ingress/bin/ | grep .; then rc=1; fi
if ! diff -q compose.yml /opt/ingress/compose.yml >/dev/null; then
    echo "compose.yml differs"
    rc=1
fi

[ "$rc" -eq 0 ] && echo "no drift"
exit "$rc"
