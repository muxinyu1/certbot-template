#!/bin/sh
set -eu

: "${DOMAIN:?DOMAIN is required in .env}"
: "${CERTBOT_EMAIL:?CERTBOT_EMAIL is required in .env}"

legacy_live_dir="/etc/letsencrypt/live/${DOMAIN}"
renewal_conf="/etc/letsencrypt/renewal/${DOMAIN}.conf"
archive_dir="/etc/letsencrypt/archive/${DOMAIN}"

cleanup_stale_live_dir() {
  if [ -d "${legacy_live_dir}" ] && [ ! -f "${renewal_conf}" ] && [ ! -d "${archive_dir}" ]; then
    echo "Removing stale live directory left by old bootstrap logic: ${legacy_live_dir}"
    rm -rf "${legacy_live_dir}"
  fi
}

echo "Waiting 15s for nginx to become ready..."
sleep 15

while :; do
  cleanup_stale_live_dir

  if certbot certonly \
    --webroot \
    -w /var/www/certbot \
    --agree-tos \
    --email "${CERTBOT_EMAIL}" \
    -d "${DOMAIN}" \
    --non-interactive \
    --keep-until-expiring \
    --rsa-key-size 4096 \
    --preferred-challenges http; then
    echo "Certificate check succeeded. Next check in 12 hours."
    sleep 12h
  else
    echo "Certificate check failed. Retrying in 5 minutes."
    sleep 5m
  fi
done