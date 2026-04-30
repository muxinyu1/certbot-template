#!/bin/sh
set -eu

: "${DOMAIN:?DOMAIN is required in .env}"
: "${CERTBOT_EMAIL:?CERTBOT_EMAIL is required in .env}"

echo "Waiting 15s for nginx to become ready..."
sleep 15

while :; do
  certbot certonly \
    --webroot \
    -w /var/www/certbot \
    --agree-tos \
    --email "${CERTBOT_EMAIL}" \
    -d "${DOMAIN}" \
    --non-interactive \
    --keep-until-expiring \
    --rsa-key-size 4096 \
    --preferred-challenges http || true

  echo "Next certificate check in 12 hours."
  sleep 12h
done