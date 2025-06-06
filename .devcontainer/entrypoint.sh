#!/bin/bash
# .devcontainer/entrypoint.sh

set -e
. /home/frappe/.nvm/nvm.sh
exec "$@"