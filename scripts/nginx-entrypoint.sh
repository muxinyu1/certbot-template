#!/bin/sh
set -eu

: "${DOMAIN:?DOMAIN is required in .env}"

mkdir -p /etc/nginx/conf.d
sed "s/__DOMAIN__/${DOMAIN}/g" /etc/nginx/templates/site.conf.template > /etc/nginx/conf.d/default.conf

if ! command -v openssl >/dev/null 2>&1; then
  apk add --no-cache openssl >/dev/null
fi

cert_dir="/etc/letsencrypt/live/${DOMAIN}"
mkdir -p "${cert_dir}"

if [ ! -s "${cert_dir}/fullchain.pem" ] || [ ! -s "${cert_dir}/privkey.pem" ]; then
  echo "No Let's Encrypt certificate yet, creating temporary self-signed certificate."
  openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
    -keyout "${cert_dir}/privkey.pem" \
    -out "${cert_dir}/fullchain.pem" \
    -subj "/CN=${DOMAIN}" >/dev/null 2>&1
fi

nginx -g 'daemon off;' &
nginx_pid=$!

while :; do
  sleep 300
  nginx -s reload >/dev/null 2>&1 || true
done &
reloader_pid=$!

trap 'kill ${reloader_pid} >/dev/null 2>&1 || true; kill ${nginx_pid} >/dev/null 2>&1 || true' INT TERM

wait "${nginx_pid}"