# infra

Конфигурация инфраструктуры VPS как код. Источник истины для `/opt/ingress`;
правки руками на сервере не выживают: `deploy.sh` синхронизирует каталог
с репозиторием, лишние файлы в управляемых подкаталогах удаляются.

## Состав

- `ingress/` — единая точка входа HTTP/HTTPS: nginx в docker compose,
  терминация TLS для `web/admin/s3.togetgo.app`, выпуск и продление
  сертификатов Let's Encrypt через certbot (webroot), MTProto-прокси mtg.

## Схема порта 443

Порт 443 слушает stream-блок nginx (`ssl_preread`, TLS не терминируется)
и маршрутизирует по SNI:

- SNI FakeTLS-домена mtg (`storage.googleapis.com`) — в контейнер
  `ingress-mtg` (MTProto-прокси, чистый TCP);
- всё остальное — в локальный http-блок на 8444, где терминируется TLS.

Оба апстрима получают PROXY protocol; http-блок восстанавливает клиентский
IP через `real_ip_header proxy_protocol`, mtg — через
`proxy-protocol-listener = true`.

FakeTLS-домен задан в двух местах и должен совпадать: stream-map в
`nginx/nginx.conf` и секрет в `/opt/ingress/secrets/mtg.toml`
(генерация — см. `ingress/secrets.example/mtg.toml`).

Приложение togetgo живет отдельно в `/opt/togetgo` и этим репозиторием
не управляется.

## Развертывание изменений

```sh
sudo ./ingress/deploy.sh
```

Скрипт копирует конфиг в `/opt/ingress`, поднимает compose-сервисы,
валидирует конфиг (`nginx -t`) и делает reload. Откат: `git checkout`
предыдущей ревизии и повторный запуск `deploy.sh`.

## Контроль дрифта

```sh
sudo ./ingress/check-drift.sh
```

Показывает расхождения `/opt/ingress` с репозиторием, ничего не меняя.
Запускать перед деплоем и при подозрении на ручные правки на сервере:
`deploy.sh` перезапишет их без предупреждения.

## Развертывание с нуля

```sh
sudo ./ingress/bootstrap.sh
```

Требуется: docker с compose-плагином, DNS доменов указывает на сервер,
порты 80/443 свободны. Скрипт создает каталоги и сеть `togetgo-public`,
поднимает nginx без https-конфига, выпускает сертификаты, затем
выполняет `deploy.sh`.

## Не хранится в репозитории

- `/opt/ingress/letsencrypt/` — сертификаты и состояние ACME (данные, не код).
- `/opt/ingress/certbot/www/` — webroot для ACME-челленджей.
- `/opt/ingress/state/` — маркер reload для renew-скрипта.
- `secrets/` — секреты (например, конфиг mtg с ключом).

## Продление сертификатов

`ingress/bin/renew-certificates.sh` продлевает сертификаты и делает reload
nginx только при фактическом обновлении. Запускается по расписанию из
root crontab (проверить: `sudo crontab -l`).
