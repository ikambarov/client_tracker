#!/usr/bin/env bash
set -euo pipefail

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

APP_NAME="client-tracker"
APP_DIR="/app"
APP_USER="ec2-user"
APP_GROUP=""
PORT="80"
GUNICORN_WORKERS="2"
GUNICORN_TIMEOUT="120"
PYTHON_BIN="${PYTHON_BIN:-python3.12}"
SERVICE_FILE="/etc/systemd/system/${APP_NAME}.service"
ENV_FILE="/etc/client-tracker.env"
LOG_DIR="/var/log/client-tracker"

DJANGO_SECRET_KEY=""
DJANGO_DEBUG="False"
DJANGO_ALLOWED_HOSTS="*"
DJANGO_CSRF_TRUSTED_ORIGINS=""
DJANGO_SECURE_SSL_REDIRECT="False"
DJANGO_SECURE_COOKIES="False"
DATABASE_TYPE="sqlite"
DB_NAME="client_tracker"
DB_USER="admin"
DB_PASSWORD=""
DB_HOST=""
DB_PORT="3306"
DB_READER_HOST=""
DB_READER_PORT=""
DB_READER_USER="admin"
DB_READER_PASSWORD=""

usage() {
  cat <<'EOF'
Usage: setup_systemd.sh [options]

Install and start the client-tracker systemd service.

App and systemd options:
  --app-dir PATH                         App folder. Default: /app
  --app-user USER                        Linux user for systemd. Default: ec2-user
  --app-group GROUP                      Linux group for systemd. Default: same as --app-user
  --port PORT                            App port. Default: 80
  --gunicorn-workers COUNT               Gunicorn worker processes. Default: 2
  --gunicorn-timeout SECONDS             Request timeout in seconds. Default: 120
  --python-bin PATH                      Python 3.12+ interpreter. Default: python3.12
  --env-file PATH                        Environment file path. Default: /etc/client-tracker.env

Django options:
  --django-secret-key VALUE              Django secret key. Default: reuse existing or generate
  --django-debug true|false              Django debug mode. Default: False
  --django-allowed-hosts VALUE           Allowed hostnames/IPs. Default: *
  --django-csrf-trusted-origins VALUE    CSRF trusted origins. Default: empty
  --django-secure-ssl-redirect true|false
                                           Secure SSL redirect. Default: False
  --django-secure-cookies true|false     Secure cookies. Default: False

Database options:
  --database-type sqlite|mysql           Database type. Default: sqlite
  --db-name NAME                         Database name. Default: client_tracker
  --db-host HOST                         Writer database host
  --db-port PORT                         Writer database port. Default: 3306
  --db-user USER                         Writer database username. Default: admin
  --db-password PASSWORD                 Writer database password. Default: empty
  --db-reader-host HOST                  Reader database host. Default: writer host
  --db-reader-port PORT                  Reader database port. Default: writer port
  --db-reader-user USER                  Reader database username. Default: admin
  --db-reader-password PASSWORD          Reader database password. Default: empty

Help:
  --help                                 Show this help
EOF
}

option_value() {
  local option="$1"
  local value="${2:-}"

  if [ -z "${value}" ]; then
    echo "${option} requires a value." >&2
    usage >&2
    exit 2
  fi

  printf '%s' "${value}"
}


while [ "$#" -gt 0 ]; do
  case "$1" in
    --app-dir) APP_DIR="$(option_value "$1" "${2:-}")"; shift 2 ;;
    --app-user) APP_USER="$(option_value "$1" "${2:-}")"; shift 2 ;;
    --app-group) APP_GROUP="$(option_value "$1" "${2:-}")"; shift 2 ;;
    --port) PORT="$(option_value "$1" "${2:-}")"; shift 2 ;;
    --gunicorn-workers) GUNICORN_WORKERS="$(option_value "$1" "${2:-}")"; shift 2 ;;
    --gunicorn-timeout) GUNICORN_TIMEOUT="$(option_value "$1" "${2:-}")"; shift 2 ;;
    --python-bin) PYTHON_BIN="$(option_value "$1" "${2:-}")"; shift 2 ;;
    --env-file) ENV_FILE="$(option_value "$1" "${2:-}")"; shift 2 ;;
    --django-secret-key) DJANGO_SECRET_KEY="$(option_value "$1" "${2:-}")"; shift 2 ;;
    --django-debug) DJANGO_DEBUG="$(option_value "$1" "${2:-}")"; shift 2 ;;
    --django-allowed-hosts) DJANGO_ALLOWED_HOSTS="$(option_value "$1" "${2:-}")"; shift 2 ;;
    --django-csrf-trusted-origins) DJANGO_CSRF_TRUSTED_ORIGINS="$(option_value "$1" "${2:-}")"; shift 2 ;;
    --django-secure-ssl-redirect) DJANGO_SECURE_SSL_REDIRECT="$(option_value "$1" "${2:-}")"; shift 2 ;;
    --django-secure-cookies) DJANGO_SECURE_COOKIES="$(option_value "$1" "${2:-}")"; shift 2 ;;
    --database-type) DATABASE_TYPE="$(option_value "$1" "${2:-}")"; shift 2 ;;
    --db-name) DB_NAME="$(option_value "$1" "${2:-}")"; shift 2 ;;
    --db-host) DB_HOST="$(option_value "$1" "${2:-}")"; shift 2 ;;
    --db-port) DB_PORT="$(option_value "$1" "${2:-}")"; shift 2 ;;
    --db-user) DB_USER="$(option_value "$1" "${2:-}")"; shift 2 ;;
    --db-password) DB_PASSWORD="$(option_value "$1" "${2:-}")"; shift 2 ;;
    --db-reader-host) DB_READER_HOST="$(option_value "$1" "${2:-}")"; shift 2 ;;
    --db-reader-port) DB_READER_PORT="$(option_value "$1" "${2:-}")"; shift 2 ;;
    --db-reader-user) DB_READER_USER="$(option_value "$1" "${2:-}")"; shift 2 ;;
    --db-reader-password) DB_READER_PASSWORD="$(option_value "$1" "${2:-}")"; shift 2 ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

APP_GROUP="${APP_GROUP:-${APP_USER}}"
SERVICE_TEMPLATE="${APP_DIR}/systemd/${APP_NAME}.service.template"

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
  "${PYTHON_BIN}" - <<'PY'
import secrets
print(secrets.token_urlsafe(50))
PY
}

install_system_packages() {
  if [ "${PYTHON_BIN}" = "python3.12" ]; then
    sudo yum install -y python3.12 python3.12-pip httpd-tools
  else
    sudo yum install -y httpd-tools
  fi
}

ensure_supported_python() {
  if ! command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
    echo "Python interpreter not found: ${PYTHON_BIN}" >&2
    echo "Install Python 3.12 or newer, or pass --python-bin PATH." >&2
    exit 2
  fi

  "${PYTHON_BIN}" - <<'PY'
import sys

if sys.version_info < (3, 12):
    version = ".".join(str(part) for part in sys.version_info[:3])
    raise SystemExit(
        f"Python 3.12 or newer is required for the pinned Django version; found {version}."
    )
PY
}

write_env_file() {
  DJANGO_SECRET_KEY="${DJANGO_SECRET_KEY:-$(existing_env_value DJANGO_SECRET_KEY)}"
  DJANGO_SECRET_KEY="${DJANGO_SECRET_KEY:-$(generate_secret_key)}"
  DB_READER_PORT="${DB_READER_PORT:-${DB_PORT}}"

  tmp_file="$(mktemp)"
  {
    printf 'DJANGO_SECRET_KEY=%s\n' "$(quote_env_value "${DJANGO_SECRET_KEY}")"
    printf 'DJANGO_DEBUG=%s\n' "$(quote_env_value "${DJANGO_DEBUG}")"
    printf 'DJANGO_ALLOWED_HOSTS=%s\n' "$(quote_env_value "${DJANGO_ALLOWED_HOSTS}")"
    printf 'DJANGO_CSRF_TRUSTED_ORIGINS=%s\n' "$(quote_env_value "${DJANGO_CSRF_TRUSTED_ORIGINS:-}")"
    printf 'DJANGO_SECURE_SSL_REDIRECT=%s\n' "$(quote_env_value "${DJANGO_SECURE_SSL_REDIRECT}")"
    printf 'DJANGO_SECURE_COOKIES=%s\n' "$(quote_env_value "${DJANGO_SECURE_COOKIES}")"
    printf 'DATABASE_TYPE=%s\n' "$(quote_env_value "${DATABASE_TYPE}")"
    printf 'DB_NAME=%s\n' "$(quote_env_value "${DB_NAME}")"
    printf 'DB_USER=%s\n' "$(quote_env_value "${DB_USER}")"
    printf 'DB_PASSWORD=%s\n' "$(quote_env_value "${DB_PASSWORD}")"
    printf 'DB_HOST=%s\n' "$(quote_env_value "${DB_HOST}")"
    printf 'DB_PORT=%s\n' "$(quote_env_value "${DB_PORT}")"
    printf 'DB_READER_HOST=%s\n' "$(quote_env_value "${DB_READER_HOST}")"
    printf 'DB_READER_PORT=%s\n' "$(quote_env_value "${DB_READER_PORT}")"
    printf 'DB_READER_USER=%s\n' "$(quote_env_value "${DB_READER_USER}")"
    printf 'DB_READER_PASSWORD=%s\n' "$(quote_env_value "${DB_READER_PASSWORD}")"
  } > "${tmp_file}"

  sudo install -m 0600 "${tmp_file}" "${ENV_FILE}"
  rm -f "${tmp_file}"
  echo "Wrote ${ENV_FILE}."

  export DJANGO_SECRET_KEY
  export DJANGO_DEBUG
  export DJANGO_ALLOWED_HOSTS
  export DJANGO_CSRF_TRUSTED_ORIGINS
  export DJANGO_SECURE_SSL_REDIRECT
  export DJANGO_SECURE_COOKIES
  export DATABASE_TYPE
  export DB_NAME
  export DB_USER
  export DB_PASSWORD
  export DB_HOST
  export DB_PORT
  export DB_READER_HOST
  export DB_READER_PORT
  export DB_READER_USER
  export DB_READER_PASSWORD
}

load_sample_data() {
  client_count="$(
    .venv/bin/python manage.py shell --no-imports -c "from tracker.models import Client; print(Client.objects.count())"
  )"

  if [ "${client_count}" = "0" ]; then
    .venv/bin/python manage.py loaddata sample_clients
  else
    echo "Skipping sample data load; ${client_count} clients already exist."
  fi
}

install_system_packages
ensure_supported_python
write_env_file

"${PYTHON_BIN}" -m venv .venv
.venv/bin/python -m pip install --upgrade pip
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python manage.py migrate
load_sample_data
.venv/bin/python manage.py collectstatic --noinput
.venv/bin/python manage.py check
sudo chown -R "${APP_USER}:${APP_GROUP}" "${APP_DIR}"

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
sudo install -d -m 0755 -o "${APP_USER}" -g "${APP_GROUP}" "${LOG_DIR}"

sudo systemctl daemon-reload
sudo systemctl enable "${APP_NAME}"
sudo systemctl restart "${APP_NAME}"
sudo systemctl --no-pager status "${APP_NAME}"

echo
echo "App URL on this instance: http://0.0.0.0/"
