#!/bin/bash
# lib/helpers.sh

source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"

info() { echo -e "${Blue}[INFO]${Color_Off} $1"; }
success() { echo -e "${Green}[SUCCESS]${Color_Off} $1"; }
warning() { echo -e "${Yellow}[WARNING]${Color_Off} $1"; }
error() { echo -e "${Red}[ERROR]${Color_Off} $1"; }
step() { echo -e "\n${Bold_Blue}>>> Step $1: $2${Color_Off}"; }

# --- Function to check command success and exit on failure ---
# Usage: some_command; check_command "description of what failed" "$DOCKER_COMPOSE_CMD" # Optional: pass compose command for logs
check_command() {
    local exit_code=$?
    local command_description="$1"
    local compose_cmd="${2:-}"

    if [ $exit_code -ne 0 ]; then
        error "Failed to $command_description (Exit Code: $exit_code). Check output above for details."
        if [[ -n "$compose_cmd" ]]; then
             if command -v ${compose_cmd%% *} &> /dev/null && $compose_cmd ps -q frappe &> /dev/null; then
                 error "Attempting to show last 50 lines of Frappe logs:"
                 $compose_cmd logs --tail=50 frappe || true 
             fi
        fi
        exit $exit_code
    fi
}