#!/bin/sh
set -e

PORT="${PORT:-8000}"
GUNICORN_WORKERS="${GUNICORN_WORKERS:-2}"
GUNICORN_TIMEOUT="${GUNICORN_TIMEOUT:-120}"
RUN_MIGRATIONS="${RUN_MIGRATIONS:-true}"
COLLECT_STATIC="${COLLECT_STATIC:-true}"
LOAD_SAMPLE_DATA="${LOAD_SAMPLE_DATA:-false}"

DJANGO_SECRET_KEY="${DJANGO_SECRET_KEY:-dev-secret-key}"
DJANGO_ALLOWED_HOSTS="${DJANGO_ALLOWED_HOSTS:-*}"

DATABASE_TYPE="${DATABASE_TYPE:-sqlite}"
DB_NAME="${DB_NAME:-client_tracker}"
DB_HOST="${DB_HOST:-}"
DB_PORT="${DB_PORT:-3306}"
DB_USER="${DB_USER:-admin}"
DB_PASSWORD="${DB_PASSWORD:-}"

usage() {
  cat <<'EOF'
Usage: scripts/start_docker.sh [options]

Start the Client Tracker Django app inside Docker.

Options:
  --port PORT                    App port inside the container. Default: 8000
  --gunicorn-workers COUNT       Gunicorn worker count. Default: 2
  --gunicorn-timeout SECONDS     Gunicorn timeout. Default: 120
  --run-migrations true|false    Run Django migrations. Default: true
  --collect-static true|false    Collect static files. Default: true
  --load-sample-data true|false  Load sample clients. Default: false

Django options:
  --django-secret-key VALUE      Django secret key. Default: dev-secret-key
  --django-allowed-hosts VALUE   Allowed hosts. Default: *

Database options:
  --database-type sqlite|mysql   Database type. Default: sqlite
  --db-name NAME                 Database name. Default: client_tracker
  --db-host HOST                 MySQL host
  --db-port PORT                 MySQL port. Default: 3306
  --db-user USER                 MySQL username. Default: admin
  --db-password PASSWORD         MySQL password

Help:
  --help                         Show this help

Environment variables:
  PORT                            Same as --port
  GUNICORN_WORKERS                Same as --gunicorn-workers
  GUNICORN_TIMEOUT                Same as --gunicorn-timeout
  RUN_MIGRATIONS                  Same as --run-migrations
  COLLECT_STATIC                  Same as --collect-static
  LOAD_SAMPLE_DATA                Same as --load-sample-data
  DJANGO_SECRET_KEY               Same as --django-secret-key
  DJANGO_ALLOWED_HOSTS            Same as --django-allowed-hosts
  DATABASE_TYPE                   Same as --database-type
  DB_NAME                         Same as --db-name
  DB_HOST                         Same as --db-host
  DB_PORT                         Same as --db-port
  DB_USER                         Same as --db-user
  DB_PASSWORD                     Same as --db-password
EOF
}

option_value() {
  if [ -z "${2:-}" ]; then
    echo "$1 needs a value."
    exit 1
  fi

  printf '%s' "$2"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help)
      usage
      exit 0
      ;;
    --port) PORT="$(option_value "$1" "${2:-}")"; shift 2 ;;
    --gunicorn-workers) GUNICORN_WORKERS="$(option_value "$1" "${2:-}")"; shift 2 ;;
    --gunicorn-timeout) GUNICORN_TIMEOUT="$(option_value "$1" "${2:-}")"; shift 2 ;;
    --run-migrations) RUN_MIGRATIONS="$(option_value "$1" "${2:-}")"; shift 2 ;;
    --collect-static) COLLECT_STATIC="$(option_value "$1" "${2:-}")"; shift 2 ;;
    --load-sample-data) LOAD_SAMPLE_DATA="$(option_value "$1" "${2:-}")"; shift 2 ;;
    --django-secret-key) DJANGO_SECRET_KEY="$(option_value "$1" "${2:-}")"; shift 2 ;;
    --django-allowed-hosts) DJANGO_ALLOWED_HOSTS="$(option_value "$1" "${2:-}")"; shift 2 ;;
    --database-type) DATABASE_TYPE="$(option_value "$1" "${2:-}")"; shift 2 ;;
    --db-name) DB_NAME="$(option_value "$1" "${2:-}")"; shift 2 ;;
    --db-host) DB_HOST="$(option_value "$1" "${2:-}")"; shift 2 ;;
    --db-port) DB_PORT="$(option_value "$1" "${2:-}")"; shift 2 ;;
    --db-user) DB_USER="$(option_value "$1" "${2:-}")"; shift 2 ;;
    --db-password) DB_PASSWORD="$(option_value "$1" "${2:-}")"; shift 2 ;;
    *)
      echo "Unknown option: $1"
      echo "Run scripts/start_docker.sh --help to see available options."
      exit 1
      ;;
  esac
done

export DJANGO_SECRET_KEY
export DJANGO_ALLOWED_HOSTS
export DATABASE_TYPE
export DB_NAME
export DB_HOST
export DB_PORT
export DB_USER
export DB_PASSWORD

if [ "${RUN_MIGRATIONS}" = "true" ]; then
  python manage.py migrate --noinput
fi

if [ "${LOAD_SAMPLE_DATA}" = "true" ]; then
  client_count="$(python manage.py shell --no-imports -c "from tracker.models import Client; print(Client.objects.count())")"
  if [ "${client_count}" = "0" ]; then
    python manage.py loaddata sample_clients
  else
    echo "Skipping sample data load; ${client_count} clients already exist."
  fi
fi

if [ "${COLLECT_STATIC}" = "true" ]; then
  python manage.py collectstatic --noinput
fi

gunicorn client_tracker.wsgi:application \
  --bind "0.0.0.0:${PORT}" \
  --workers "${GUNICORN_WORKERS}" \
  --timeout "${GUNICORN_TIMEOUT}"
