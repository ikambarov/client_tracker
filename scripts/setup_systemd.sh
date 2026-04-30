#!/usr/bin/env bash
set -euo pipefail

APP_NAME="client-tracker"
APP_DIR="${APP_DIR:-${HOME}/client_tracker}"
APP_USER="${APP_USER:-ec2-user}"
APP_GROUP="${APP_GROUP:-${APP_USER}}"
PORT="${PORT:-80}"
GUNICORN_WORKERS="${GUNICORN_WORKERS:-2}"
GUNICORN_TIMEOUT="${GUNICORN_TIMEOUT:-120}"
SERVICE_TEMPLATE="${APP_DIR}/systemd/${APP_NAME}.service.template"
SERVICE_FILE="/etc/systemd/system/${APP_NAME}.service"
ENV_FILE="${ENV_FILE:-/etc/client-tracker.env}"

cd "${APP_DIR}"

quote_env_value() {
  local value="${1:-}"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//\$/\\\$}"
  value="${value//\`/\\\`}"
  printf '"%s"' "${value}"
}

existing_env_value() {
  local name="$1"

  if sudo test -f "${ENV_FILE}"; then
    sudo grep -E "^${name}=" "${ENV_FILE}" | tail -n 1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//' || true
  fi
}

generate_secret_key() {
  python3 - <<'PY'
import secrets
print(secrets.token_urlsafe(50))
PY
}

write_env_file() {
  DJANGO_SECRET_KEY="${DJANGO_SECRET_KEY:-$(existing_env_value DJANGO_SECRET_KEY)}"
  DJANGO_SECRET_KEY="${DJANGO_SECRET_KEY:-$(generate_secret_key)}"
  DJANGO_DEBUG="${DJANGO_DEBUG:-False}"
  DJANGO_ALLOWED_HOSTS="${DJANGO_ALLOWED_HOSTS:-*}"
  DJANGO_CSRF_TRUSTED_ORIGINS="${DJANGO_CSRF_TRUSTED_ORIGINS:-}"
  DJANGO_SECURE_SSL_REDIRECT="${DJANGO_SECURE_SSL_REDIRECT:-False}"
  DJANGO_SECURE_COOKIES="${DJANGO_SECURE_COOKIES:-False}"

  tmp_file="$(mktemp)"
  {
    printf 'DJANGO_SECRET_KEY=%s\n' "$(quote_env_value "${DJANGO_SECRET_KEY}")"
    printf 'DJANGO_DEBUG=%s\n' "$(quote_env_value "${DJANGO_DEBUG}")"
    printf 'DJANGO_ALLOWED_HOSTS=%s\n' "$(quote_env_value "${DJANGO_ALLOWED_HOSTS}")"
    printf 'DJANGO_CSRF_TRUSTED_ORIGINS=%s\n' "$(quote_env_value "${DJANGO_CSRF_TRUSTED_ORIGINS:-}")"
    printf 'DJANGO_SECURE_SSL_REDIRECT=%s\n' "$(quote_env_value "${DJANGO_SECURE_SSL_REDIRECT}")"
    printf 'DJANGO_SECURE_COOKIES=%s\n' "$(quote_env_value "${DJANGO_SECURE_COOKIES}")"
    printf 'DATABASE_TYPE=%s\n' "$(quote_env_value "${DATABASE_TYPE:-sqlite}")"
    printf 'DB_NAME=%s\n' "$(quote_env_value "${DB_NAME:-client_tracker}")"
    printf 'DB_USER=%s\n' "$(quote_env_value "${DB_USER:-admin}")"
    printf 'DB_PASSWORD=%s\n' "$(quote_env_value "${DB_PASSWORD:-}")"
    printf 'DB_HOST=%s\n' "$(quote_env_value "${DB_HOST:-}")"
    printf 'DB_PORT=%s\n' "$(quote_env_value "${DB_PORT:-3306}")"
    printf 'DB_READER_HOST=%s\n' "$(quote_env_value "${DB_READER_HOST:-}")"
    printf 'DB_READER_PORT=%s\n' "$(quote_env_value "${DB_READER_PORT:-${DB_PORT:-3306}}")"
    printf 'DB_READER_USER=%s\n' "$(quote_env_value "${DB_READER_USER:-admin}")"
    printf 'DB_READER_PASSWORD=%s\n' "$(quote_env_value "${DB_READER_PASSWORD:-}")"
  } > "${tmp_file}"

  sudo install -m 0600 "${tmp_file}" "${ENV_FILE}"
  rm -f "${tmp_file}"
  echo "Wrote ${ENV_FILE} from environment variables."

  export DJANGO_SECRET_KEY
  export DJANGO_DEBUG
  export DJANGO_ALLOWED_HOSTS
  export DJANGO_CSRF_TRUSTED_ORIGINS
  export DJANGO_SECURE_SSL_REDIRECT
  export DJANGO_SECURE_COOKIES
  export DATABASE_TYPE="${DATABASE_TYPE:-sqlite}"
  export DB_NAME="${DB_NAME:-client_tracker}"
  export DB_USER="${DB_USER:-admin}"
  export DB_PASSWORD="${DB_PASSWORD:-}"
  export DB_HOST="${DB_HOST:-}"
  export DB_PORT="${DB_PORT:-3306}"
  export DB_READER_HOST="${DB_READER_HOST:-}"
  export DB_READER_PORT="${DB_READER_PORT:-${DB_PORT}}"
  export DB_READER_USER="${DB_READER_USER:-admin}"
  export DB_READER_PASSWORD="${DB_READER_PASSWORD:-}"
}

load_sample_data() {
  client_count="$(
    .venv/bin/python manage.py shell -c "from tracker.models import Client; print(Client.objects.count())"
  )"

  if [ "${client_count}" = "0" ]; then
    .venv/bin/python manage.py loaddata sample_clients
  else
    echo "Skipping sample data load; ${client_count} clients already exist."
  fi
}

write_env_file

sudo yum install -y python3 python3-pip httpd-tools

python3 -m venv .venv
.venv/bin/python -m pip install --upgrade pip
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python manage.py migrate
load_sample_data
.venv/bin/python manage.py collectstatic --noinput
.venv/bin/python manage.py check

tmp_service="$(mktemp)"
sed \
  -e "s#__APP_DIR__#${APP_DIR}#g" \
  -e "s#__APP_USER__#${APP_USER}#g" \
  -e "s#__APP_GROUP__#${APP_GROUP}#g" \
  -e "s#__ENV_FILE__#${ENV_FILE}#g" \
  -e "s#__PORT__#${PORT}#g" \
  -e "s#__GUNICORN_WORKERS__#${GUNICORN_WORKERS}#g" \
  -e "s#__GUNICORN_TIMEOUT__#${GUNICORN_TIMEOUT}#g" \
  "${SERVICE_TEMPLATE}" > "${tmp_service}"
sudo install -m 0644 "${tmp_service}" "${SERVICE_FILE}"
rm -f "${tmp_service}"

sudo systemctl daemon-reload
sudo systemctl enable "${APP_NAME}"
sudo systemctl restart "${APP_NAME}"
sudo systemctl --no-pager status "${APP_NAME}"

echo
echo "App URL on this instance: http://0.0.0.0/"
