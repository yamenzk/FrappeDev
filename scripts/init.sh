#!/bin/bash
# scripts/init.sh
set -e

echo "--- Running Frappe Initialization ---"

if [ -f "/workspace/frappe-bench/Procfile" ]; then
    echo "Bench already exists, skipping initialization."
    exit 0
fi

echo "Bench not found. Initializing a new one..."
echo "Frappe Branch: ${FRAPPE_BRANCH}"
echo "Python Version: ${PYTHON_VERSION_FOR_BENCH}"

cd /workspace

bench init \
  --ignore-exist \
  --skip-redis-config-generation \
  --python "${PYTHON_VERSION_FOR_BENCH}" \
  --frappe-path https://github.com/frappe/frappe \
  --frappe-branch "${FRAPPE_BRANCH}" \
  frappe-bench

cd /workspace/frappe-bench

bench set-mariadb-host mariadb
bench set-redis-cache-host redis://redis-cache:6379
bench set-redis-queue-host redis://redis-queue:6379
bench set-redis-socketio-host redis://redis-socketio:6379

sed -i '/redis/d' ./Procfile

DEFAULT_SITE="dev.localhost"
bench new-site "${DEFAULT_SITE}" \
  --mariadb-root-password "123" \
  --admin-password "admin" \
  --no-mariadb-socket \
  --db-root-username root

# --- Set Site Configurations for Development ---
echo "Applying development configurations to site: ${DEFAULT_SITE}"
bench --site "${DEFAULT_SITE}" set-config developer_mode 1
bench --site "${DEFAULT_SITE}" set-config ignore_csrf 1
bench --site "${DEFAULT_SITE}" set-config allow_cors '*'
bench use "${DEFAULT_SITE}"

echo "--- Frappe Initialization Complete ---"