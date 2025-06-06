#!/bin/bash
# scripts/init.sh - Runs inside the frappe container during setup.

set -e # Exit immediately if a command exits with a non-zero status.

echo "--- Running Frappe Initialization ---"

# The bench is initialized in a mounted volume, so we check if it's already been set up.
if [ -f "/workspace/frappe-bench/Procfile" ]; then
    echo "Bench already exists, skipping initialization."
    exit 0
fi

echo "Bench not found. Initializing a new one..."
echo "Using Frappe Branch: ${FRAPPE_BRANCH}"

# Make sure we're in the right directory
cd /workspace

# Initialize the bench
bench init \
  --ignore-exist \
  --skip-redis-config-generation \
  --frappe-path https://github.com/frappe/frappe \
  --frappe-branch "${FRAPPE_BRANCH}" \
  frappe-bench

# CRITICAL: Change to the bench directory for all subsequent commands
cd /workspace/frappe-bench

# Configure bench to use the containerized services
bench set-mariadb-host mariadb
bench set-redis-cache-host redis://redis-cache:6379
bench set-redis-queue-host redis://redis-queue:6379
bench set-redis-socketio-host redis://redis-socketio:6379

# Remove redis from Procfile since it's managed by Docker Compose
sed -i '/redis/d' ./Procfile

# Create the first site
DEFAULT_SITE="dev.localhost"
bench new-site "${DEFAULT_SITE}" \
  --mariadb-root-password "123" \
  --admin-password "admin" \
  --no-mariadb-socket

# Enable developer mode
bench --site "${DEFAULT_SITE}" set-config developer_mode 1
bench use "${DEFAULT_SITE}"

echo "--- Frappe Initialization Complete ---"
echo "You can now start the development server by running 'fh start'"