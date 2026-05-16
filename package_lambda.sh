#!/usr/bin/env bash
set -euo pipefail

PYTHON_BIN="${PYTHON_BIN:-python3.14}"
BUILD_DIR=".lambda_build"
DIST_DIR="dist"
ZIP_FILE="${DIST_DIR}/client-tracker-lambda.zip"

if ! command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
  echo "Missing Python interpreter: ${PYTHON_BIN}" >&2
  echo "Set PYTHON_BIN to the Python version that matches your Lambda runtime." >&2
  exit 1
fi

if ! command -v zip >/dev/null 2>&1; then
  echo "Missing required command: zip" >&2
  exit 1
fi

if ! command -v unzip >/dev/null 2>&1; then
  echo "Missing required command: unzip" >&2
  exit 1
fi

rm -rf "${BUILD_DIR}" "${ZIP_FILE}"
mkdir -p "${BUILD_DIR}" "${DIST_DIR}"

"${PYTHON_BIN}" -m pip install -r requirements.txt -t "${BUILD_DIR}"

cp -R client_tracker "${BUILD_DIR}/client_tracker"
cp -R tracker "${BUILD_DIR}/tracker"
cp -R templates "${BUILD_DIR}/templates"
cp -R static "${BUILD_DIR}/static"
cp manage.py "${BUILD_DIR}/manage.py"
cp lambda_function.py "${BUILD_DIR}/lambda_function.py"

(
  cd "${BUILD_DIR}"
  DJANGO_SECRET_KEY="${DJANGO_SECRET_KEY:-lambda-package-build-secret}" \
    DATABASE_TYPE="${PACKAGE_DATABASE_TYPE:-sqlite}" \
    PYTHONPATH="${PWD}" \
    "${PYTHON_BIN}" manage.py collectstatic --noinput

  DJANGO_SECRET_KEY="${DJANGO_SECRET_KEY:-lambda-package-build-secret}" \
    DATABASE_TYPE="${PACKAGE_DATABASE_TYPE:-sqlite}" \
    PYTHONPATH="${PWD}" \
    PYTHONDONTWRITEBYTECODE=1 \
    "${PYTHON_BIN}" -c "import apig_wsgi; import lambda_function"
)

find "${BUILD_DIR}" -type d -name '__pycache__' -prune -exec rm -rf {} +
find "${BUILD_DIR}" -type f -name '*.pyc' -delete

(
  cd "${BUILD_DIR}"
  zip -qr "../${ZIP_FILE}" .
)

ZIP_LIST="${BUILD_DIR}/zip-list.txt"
unzip -Z -1 "${ZIP_FILE}" > "${ZIP_LIST}"

if ! grep -Fxq 'lambda_function.py' "${ZIP_LIST}"; then
  echo "Package verification failed: lambda_function.py missing from ${ZIP_FILE}" >&2
  exit 1
fi

if ! grep -Fxq 'client_tracker/settings.py' "${ZIP_LIST}"; then
  echo "Package verification failed: client_tracker/settings.py missing from ${ZIP_FILE}" >&2
  exit 1
fi

if ! grep -Fxq 'tracker/views.py' "${ZIP_LIST}"; then
  echo "Package verification failed: tracker/views.py missing from ${ZIP_FILE}" >&2
  exit 1
fi

ls -lh "${ZIP_FILE}"
