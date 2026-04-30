#!/bin/sh
set -eu

: "${DOMAIN:?DOMAIN is required in .env}"

mkdir -p /etc/nginx/conf.d

if ! command -v openssl >/dev/null 2>&1; then
  apk add --no-cache openssl >/dev/null
fi

le_cert_dir="/etc/letsencrypt/live/${DOMAIN}"
runtime_cert_dir="/etc/nginx/certs"
tmp_cert="${runtime_cert_dir}/selfsigned-fullchain.pem"
tmp_key="${runtime_cert_dir}/selfsigned-privkey.pem"
active_cert="${runtime_cert_dir}/fullchain.pem"
active_key="${runtime_cert_dir}/privkey.pem"

mkdir -p "${runtime_cert_dir}"

render_nginx_conf() {
  sed \
    -e "s|__DOMAIN__|${DOMAIN}|g" \
    -e "s|__SSL_CERT_PATH__|${active_cert}|g" \
    -e "s|__SSL_KEY_PATH__|${active_key}|g" \
    /etc/nginx/templates/site.conf.template > /etc/nginx/conf.d/default.conf
}

resolve_le_cert_dir() {
  best_dir=""
  best_mtime=0

  for d in "${le_cert_dir}" "/etc/letsencrypt/live/${DOMAIN}-"*; do
    cert_file="${d}/fullchain.pem"
    key_file="${d}/privkey.pem"

    if [ ! -s "${cert_file}" ] || [ ! -s "${key_file}" ]; then
      continue
    fi

    mtime=$(stat -c %Y "${cert_file}" 2>/dev/null || echo 0)
    if [ "${mtime}" -ge "${best_mtime}" ]; then
      best_mtime="${mtime}"
      best_dir="${d}"
    fi
  done

  if [ -n "${best_dir}" ]; then
    echo "${best_dir}"
    return 0
  fi

  return 1
}

link_active_cert() {
  if selected_dir=$(resolve_le_cert_dir); then
    ln -sf "${selected_dir}/fullchain.pem" "${active_cert}"
    ln -sf "${selected_dir}/privkey.pem" "${active_key}"
    return 0
  fi

  ln -sf "${tmp_cert}" "${active_cert}"
  ln -sf "${tmp_key}" "${active_key}"
  return 1
}

if [ ! -s "${tmp_cert}" ] || [ ! -s "${tmp_key}" ]; then
  echo "Creating temporary self-signed certificate for bootstrap."
  openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
    -keyout "${tmp_key}" \
    -out "${tmp_cert}" \
    -subj "/CN=${DOMAIN}" >/dev/null 2>&1
fi

if link_active_cert; then
  echo "Using Let's Encrypt certificate for ${DOMAIN}."
else
  echo "Let's Encrypt certificate not available yet, using temporary certificate."
fi

render_nginx_conf

nginx -g 'daemon off;' &
nginx_pid=$!

while :; do
  sleep 30
  link_active_cert >/dev/null 2>&1 || true
  render_nginx_conf
  nginx -s reload >/dev/null 2>&1 || true
done &
reloader_pid=$!

trap 'kill ${reloader_pid} >/dev/null 2>&1 || true; kill ${nginx_pid} >/dev/null 2>&1 || true' INT TERM

wait "${nginx_pid}"