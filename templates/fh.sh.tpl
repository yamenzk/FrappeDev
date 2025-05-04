#!/bin/bash
# Helper script for common Frappe development operations (Enhanced CLI Version)
# Generated for instance: __INSTANCE_NAME_PLACEHOLDER__

# --- Colors (Copied from lib/colors.sh for standalone use) ---
Color_Off='\033[0m'       # Text Reset
Black='\033[0;30m'; Red='\033[0;31m'; Green='\033[0;32m'; Yellow='\033[0;33m'; Blue='\033[0;34m'; Purple='\033[0;35m'; Cyan='\033[0;36m'; White='\033[0;37m'
BBlack='\033[1;30m'; BRed='\033[1;31m'; BGreen='\033[1;32m'; BYellow='\033[1;33m'; BBlue='\033[1;34m'; BPurple='\033[1;35m'; BCyan='\033[1;36m'; BWhite='\033[1;37m'
Bold_Blue=$BBlue; Bold_Green=$BGreen; Bold_Yellow=$BYellow; Bold_Red=$BRed

# --- Helper Echo (Copied from lib/helpers.sh for standalone use) ---
info() { echo -e "${Blue}[INFO]${Color_Off} $1"; }
success() { echo -e "${Green}[SUCCESS]${Color_Off} $1"; }
warning() { echo -e "${Yellow}[WARNING]${Color_Off} $1"; }
error() { echo -e "${Red}[ERROR]${Color_Off} $1"; }

# --- Configuration ---
BENCH_DIR="/workspace/frappe-bench"
DB_ROOT_PASSWORD="123" # Default password set in docker-compose/init.sh

# --- Detect Compose Command ---
# Function to detect the available Docker Compose command (copied from lib/docker_utils.sh)
get_docker_compose_command() {
    if docker compose version &> /dev/null; then
        echo "docker compose"
    elif command -v docker-compose &> /dev/null; then
        echo "docker-compose"
    else
        echo "" # Return empty string if neither is found
    fi
}

DOCKER_COMPOSE_CMD=$(get_docker_compose_command)
if [[ -z "$DOCKER_COMPOSE_CMD" ]]; then
    error "Docker Compose command not found."
    exit 1
fi
# info "Using Docker Compose command: '$DOCKER_COMPOSE_CMD'" # Optional: uncomment for debugging

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTANCE_NAME=$(basename "$SCRIPT_DIR")
# Ensure we are in the instance directory when running docker compose commands
cd "$SCRIPT_DIR" || exit 1

# --- Helper Functions for Running Commands in Container ---

# run_bench: Executes a bench command inside the container's bench directory
run_bench() {
    local args=("$@")
    local interactive_flag=false
    local docker_opts="-T" # Default: non-interactive
    if [[ "${args[-1]}" == "--interactive" ]]; then
        interactive_flag=true; docker_opts="-it"; unset 'args[-1]';
    fi
    info "Running in container: bench ${args[*]}"
    $DOCKER_COMPOSE_CMD exec $docker_opts -w "$BENCH_DIR" frappe bench "${args[@]}"
    local exit_code=$?; if [ $exit_code -ne 0 ]; then error "Bench command failed (Exit Code: $exit_code)."; fi
    return $exit_code
}

# run_in_container: Executes an arbitrary command inside the container
run_in_container() {
    local args=("$@")
    local interactive_flag=false
    local docker_opts="-T" # Default: non-interactive
    if [[ "${args[-1]}" == "--interactive" ]]; then
        interactive_flag=true; docker_opts="-it"; unset 'args[-1]';
    fi
    info "Running in container: ${args[*]}"
    $DOCKER_COMPOSE_CMD exec $docker_opts frappe bash -c "${args[*]}"
     local exit_code=$?; if [ $exit_code -ne 0 ]; then error "Container command failed (Exit Code: $exit_code)."; fi
    return $exit_code
}

# get_config_value: Retrieves a config value from bench (site or global)
get_config_value() {
    local scope=$1; local key=""; local site_arg=""
    if [[ "$scope" == "site" ]]; then
        if [[ -z "$2" || -z "$3" ]]; then error "Usage: get_config_value site <site_name> <key>"; return 1; fi
        site_arg="--site $2"; key="$3";
    elif [[ "$scope" == "global" ]]; then
        if [[ -z "$2" ]]; then error "Usage: get_config_value global <key>"; return 1; fi; key="$2";
    else error "Invalid scope '$scope'. Use 'site' or 'global'."; return 1; fi
    # Execute quietly, grab only the last line which should be the value
    $DOCKER_COMPOSE_CMD exec -T -w "$BENCH_DIR" frappe bench $site_arg get-config "$key" 2>/dev/null | tail -n 1
    # Check the exit status of the *docker exec* command itself
    # $? reflects the exit status of tail, PIPESTATUS[0] reflects bench command status
    if [ ${PIPESTATUS[0]} -ne 0 ]; then return 1; fi # Return error if bench get-config failed
    return 0 # Return success if docker exec and tail worked
}


# --- Main Command Handling ---

case "$1" in
    start)
        info "Starting Frappe containers for instance '$INSTANCE_NAME'..."
        $DOCKER_COMPOSE_CMD up -d
        success "Containers started. Access default site at http://localhost:8000"
        ;;
    stop)
        info "Stopping Frappe containers for instance '$INSTANCE_NAME'..."
        $DOCKER_COMPOSE_CMD down
        success "Containers stopped."
        ;;
    restart)
        info "Restarting Frappe containers for instance '$INSTANCE_NAME'..."
        $DOCKER_COMPOSE_CMD down
        $DOCKER_COMPOSE_CMD up -d
        success "Containers restarted. Access default site at http://localhost:8000"
        ;;
    shell)
        info "Opening shell in Frappe container (at $BENCH_DIR) for instance '$INSTANCE_NAME'..."
        $DOCKER_COMPOSE_CMD exec -it -w "$BENCH_DIR" frappe bash # Always interactive
        ;;
    dev)
        info "Starting Frappe development server inside container (bench start) for instance '$INSTANCE_NAME'..."
        run_bench start --interactive # Needs interactive
        ;;
    init)
        warning "Re-running initialization script (scripts/init.sh) for instance '$INSTANCE_NAME'."
        warning "This is usually only needed on first setup or if init failed."
        read -p "Are you sure? (y/n): " -n 1 -r; echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            info "Ensuring tools (nc, mysql, redis) are installed in container (as root)..."
            # Run as root just for apt-get
            $DOCKER_COMPOSE_CMD exec -T -u root frappe bash -c "export DEBIAN_FRONTEND=noninteractive && apt-get update -qq >/dev/null && apt-get install -y -qq --no-install-recommends netcat-openbsd mariadb-client redis-tools apt-utils > /dev/null"
            if [ $? -ne 0 ]; then error "Failed to install tools. Aborting init."; exit 1; fi
            info "Executing scripts/init.sh inside container (as user frappe)..."
            # Run init script as frappe user, interactively to see output
            $DOCKER_COMPOSE_CMD exec -it -u frappe frappe bash /workspace/scripts/init.sh
            if [ $? -eq 0 ]; then success "Init script finished."; else error "Init script failed."; fi
        else info "Operation cancelled."; fi
        ;;
    logs)
        info "Showing logs from Frappe container for instance '$INSTANCE_NAME' (Ctrl+C to exit)..."
        $DOCKER_COMPOSE_CMD logs -f frappe
        ;;
    status)
        info "Container status for instance '$INSTANCE_NAME':"
        $DOCKER_COMPOSE_CMD ps
        ;;
    build-app)
        shift # Remove 'build-app'
        if [ -z "$1" ]; then error "App name required. Usage: $0 build-app <app_name>"; exit 1; fi
        run_bench build --app "$1" && success "Assets built for app '$1'."
        ;;
    setup-ssh)
        info "Setting up SSH for Git access inside container for instance '$INSTANCE_NAME'..."

        # --- Check mount status INSIDE the container ---
        # Check involves: 1. Does dir exist? 2. If yes, can we write a temp file?
        mount_status_cmd="if [ -d /home/frappe/.ssh ]; then if touch /home/frappe/.ssh/.fh_write_test 2>/dev/null; then rm /home/frappe/.ssh/.fh_write_test; echo 'writable'; else echo 'readonly'; fi; else echo 'missing'; fi"
        # Run the check quietly using exec -T, capture output
        mount_info=$($DOCKER_COMPOSE_CMD exec -T frappe bash -c "$mount_status_cmd")
        mount_check_exit_code=$?

        if [ $mount_check_exit_code -ne 0 ]; then
            error "Failed to check SSH directory status inside the container. Docker exec might be failing or container not running."
             # Attempt to determine if container is running
             if ! $DOCKER_COMPOSE_CMD ps -q frappe > /dev/null 2>&1; then
                 error "The 'frappe' container does not appear to be running. Start it with '$0 start'."
             fi
            exit 1
        fi

        # --- User Interaction ---
        read -p "Use host SSH keys (requires ~/.ssh mounted read-only)? (Y/n): " -n 1 -r; echo
        if [[ -z "$REPLY" || $REPLY =~ ^[Yy]$ ]]; then
            # --- Use Host Keys Path ---
            case "$mount_info" in
                "writable")
                    warning "/home/frappe/.ssh exists inside the container but appears WRITABLE."
                    warning "For host keys, it SHOULD be mounted read-only (e.g., ~/.ssh:/home/frappe/.ssh:ro)."
                    warning "Proceeding, but SSH might use unexpected keys if container modified ~/.ssh."
                    ;;
                "readonly")
                    success "/home/frappe/.ssh found and is read-only (correct for host key mount)."
                    ;;
                "missing")
                    error "Host keys selected, but /home/frappe/.ssh mount not found inside container."
                    error "Ensure a volume like '- ~/.ssh:/home/frappe/.ssh:ro' is present and correct in docker-compose.yml"
                    error "Cannot proceed with host keys without the mount."
                    exit 1
                    ;;
                *)
                    error "Unknown mount status: '$mount_info'. Check container manually using '$0 shell'."
                    exit 1
                    ;;
            esac
            info "Assuming host SSH keys are configured. Test with: ${Cyan}$0 exec ssh -T git@github.com${Color_Off}"

        else
            # --- Generate New Keys Path ---
            target_key_path=""
            key_gen_cmd=""

            case "$mount_info" in
                "writable" | "missing")
                    # Standard location is writable or doesn't exist yet (parent /home/frappe assumed writable)
                    target_key_path="/home/frappe/.ssh/id_ed25519"
                    info "Generating new keys in standard location (${target_key_path})."
                    # Need to ensure .ssh dir exists and has correct permissions before keygen
                    key_gen_cmd="mkdir -p /home/frappe/.ssh && chmod 700 /home/frappe/.ssh && ssh-keygen -t ed25519 -f \"${target_key_path}\" -N \"\" -C \"frappe-dev-$(date +%Y-%m-%d)\" && chmod 600 \"${target_key_path}\" && chmod 644 \"${target_key_path}.pub\""
                    ;;
                "readonly")
                    # Standard location exists but is read-only (likely host mount)
                    target_key_path="/home/frappe/id_ed25519_generated" # Generate in home dir instead
                    warning "/home/frappe/.ssh is read-only (likely host mount). Generating new keys elsewhere."
                    info "Generating new keys in ${target_key_path} instead."
                    # No need for mkdir/chmod on .ssh as it exists (read-only)
                    key_gen_cmd="ssh-keygen -t ed25519 -f \"${target_key_path}\" -N \"\" -C \"frappe-dev-$(date +%Y-%m-%d)\" && chmod 600 \"${target_key_path}\" && chmod 644 \"${target_key_path}.pub\""
                    ;;
                 *)
                    error "Unknown mount status: '$mount_info'. Cannot determine where to generate keys."
                    exit 1
                    ;;
            esac

            # Ask confirmation *after* determining the path
            read -p "Generate a new SSH keypair (ed25519, no passphrase) at '${target_key_path}'? (y/n): " -n 1 -r; echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                info "Generating SSH key inside the Frappe container..."
                run_in_container "$key_gen_cmd" # Execute the determined command
                key_gen_exit_code=$?
                if [ $key_gen_exit_code -eq 0 ]; then
                     success "SSH key generated."

                     # --- Improved Public Key Display ---
                     echo -e "\n${Bold_Yellow}=============== ADD THIS PUBLIC KEY TO GITHUB/GITLAB ===============${Color_Off}"
                     echo -e "${Cyan}Copy the entire line below (starting with 'ssh-'):${Color_Off}\n"
                     # Capture the key content directly, avoid showing the 'cat' command here
                     public_key_content=$($DOCKER_COMPOSE_CMD exec -T frappe cat "${target_key_path}.pub" 2>/dev/null)
                     # Check if key content was captured
                     if [ -n "$public_key_content" ]; then
                         # Print with indentation and color for clarity
                         echo -e "  ${Bold_Green}${public_key_content}${Color_Off}\n"
                     else
                         # Fallback if capturing failed
                         error "Could not retrieve public key content from ${target_key_path}.pub"
                         warning "Attempting fallback display:"
                         run_in_container "cat \"${target_key_path}.pub\"" # Fallback display
                     fi
                     echo -e "${Bold_Yellow}======================= END OF PUBLIC KEY ========================${Color_Off}\n"
                     # --- End Improved Display ---

                     info "Private key saved at: ${target_key_path} (inside the container)"

                     # --- Configure System SSH Client (Fix: Removed 'local') ---
                     # If the key was generated in the alternate path due to read-only .ssh
                     if [[ "$target_key_path" == "/home/frappe/id_ed25519_generated" ]]; then
                         info "Attempting to configure system SSH client to recognize the generated key..."
                         identity_line="IdentityFile ${target_key_path}" # No 'local'
                         ssh_config_file="/etc/ssh/ssh_config"         # No 'local'
                         # Check if the line already exists (requires grep in container)
                         # Use docker exec directly for root commands for simplicity here
                         if ! $DOCKER_COMPOSE_CMD exec -T -u root frappe grep -qF "$identity_line" "$ssh_config_file"; then
                             info "Adding '$identity_line' to $ssh_config_file"
                             $DOCKER_COMPOSE_CMD exec -T -u root frappe bash -c "echo \"$identity_line\" >> \"$ssh_config_file\""
                             if [ $? -eq 0 ]; then
                                 success "System SSH client configured to check $target_key_path."
                             else
                                 error "Failed to update $ssh_config_file. You may need to use 'ssh -i $target_key_path'."
                             fi
                         else
                             info "System SSH client already configured for $target_key_path."
                         fi
                     fi
                     # --- End Configure System SSH Client ---

                     # Updated warning logic
                     if [[ "$mount_info" == "readonly" ]]; then
                        warning "Ensure the public key displayed above is added to GitHub/GitLab."
                        if [[ "$target_key_path" == "/home/frappe/id_ed25519_generated" ]]; then
                             # Only show this specific warning if the key is outside .ssh and config might have failed
                             # Check if the command to add the IdentityFile likely failed (a bit indirect)
                             check_config_cmd="$DOCKER_COMPOSE_CMD exec -T -u root frappe grep -qF \"$identity_line\" \"$ssh_config_file\""
                             if ! eval "$check_config_cmd"; then
                                warning "If auto-config failed, you might need 'ssh -i $target_key_path'."
                             fi
                        fi
                        warning "Using host keys (option 'y') can be simpler if host key is registered on GitHub/GitLab."
                     fi
                     info "Test the connection using: ${Cyan}$0 exec ssh -T git@github.com${Color_Off} (should work automatically if public key added)"
                 else error "SSH key generation failed."; fi
            else info "Skipping key generation. SSH may not work for private repos without keys."; fi
        fi
        ;;
    exec)
        shift # Remove 'exec' from arguments
        if [ -z "$*" ]; then error "No command provided to execute. Usage: $0 exec <command_to_run_in_container>"; exit 1; fi
        if [[ "$1" == "bash" || "$1" == "sh" || "$1" == "ssh" ]]; then # Make ssh interactive too
            run_in_container "$@" --interactive
        else run_in_container "$@"; fi
        ;;
    clean)
        warning "This will stop and REMOVE all containers and data (volumes) for instance '$INSTANCE_NAME'!"
        warning "Local code in './frappe-bench' will remain."
        read -p "Are you sure? (y/n): " -n 1 -r; echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            info "Stopping containers and removing volumes for '$INSTANCE_NAME'..."
            $DOCKER_COMPOSE_CMD down -v
            success "Instance '$INSTANCE_NAME' cleaned. All container data lost."
        else info "Operation cancelled."; fi
        ;;
    
    reset-default-site)
        info "This will attempt to remove the 'default_site' setting from common_site_config.json for instance '$INSTANCE_NAME'."
        warning "The effective default site will then depend on the last site set via 'bench use'."
        read -p "Are you sure you want to remove the explicit default site setting? (y/n): " -n 1 -r; echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Using bench config command to remove the key
            run_bench config remove-common-config default_site
            if [ $? -eq 0 ]; then
                success "Attempted to remove 'default_site' from common config."
                info "Please restart bench ('$0 dev') for changes to potentially take effect."
            else
                # Note: bench config might return non-zero if key doesn't exist, which is okay.
                # We might need more robust error checking depending on bench version behavior.
                warning "Bench command finished. The key might have already been absent or an error occurred."
            fi
        else info "Operation cancelled."; fi
        ;;

    enable-dns-multitenant)
        info "Setting 'dns_multitenant' to 'true' (on) in common_site_config.json for instance '$INSTANCE_NAME'..."
        # Use bench config command
        run_bench config dns_multitenant on
        if [ $? -eq 0 ]; then
            success "'dns_multitenant' set to 'on'."
            info "Please restart bench ('$0 dev') for changes to take effect."
        else error "Failed to set 'dns_multitenant'."; fi
        ;;

    disable-serve-default-site)
        info "This will set 'serve_default_site' to 'false' (0) in common_site_config.json for instance '$INSTANCE_NAME'."
        warning "This might help ensure hostname matching works correctly with DNS multitenancy."
        read -p "Are you sure you want to set 'serve_default_site' to false? (y/n): " -n 1 -r; echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Use bench set-config -g (like developer_mode) and '0' for false
            run_bench set-config -g serve_default_site 0
            if [ $? -eq 0 ]; then
                success "'serve_default_site' set to '0' (false)."
                info "Please restart bench ('$0 dev') for changes to take effect."
            else error "Failed to set 'serve_default_site'."; fi
        else info "Operation cancelled."; fi
        ;;

    setup-nginx)
        info "Running 'bench setup nginx' for instance '$INSTANCE_NAME'..."
        warning "This command regenerates Nginx configuration files."
        warning "${Bold_Red}This is typically used for PRODUCTION setups using Nginx.${Color_Off}"
        warning "It might have limited effect or be unnecessary in this Dockerized 'bench start' development environment."
        read -p "Proceed anyway? (y/n): " -n 1 -r; echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            run_bench setup nginx
             if [ $? -eq 0 ]; then
                 success "'bench setup nginx' completed."
                 info "If Nginx were running as the primary server, you would typically reload it now (e.g., 'sudo systemctl reload nginx')."
            else error "'bench setup nginx' failed."; fi
        else info "Operation cancelled."; fi
        ;;

    # --- NEW/MERGED COMMANDS ---
    update)
        info "Running 'bench update' (updates bench, Frappe, all installed apps) for instance '$INSTANCE_NAME'..."
        warning "Watch output for merge conflicts or errors. Run with --interactive."
        run_bench update --interactive # Often requires interactive prompts
        if [ $? -eq 0 ]; then
            success "'bench update' completed."
            read -p "Run database migrations for all sites now? (Y/n): " -n 1 -r; echo
            if [[ -z "$REPLY" || $REPLY =~ ^[Yy]$ ]]; then
                 run_bench migrate && success "Migrations completed." || error "Migration failed."
            else info "Skipping migrations. Run '$0 migrate-all' or '$0 migrate-site <site>' later."; fi
        else error "'bench update' failed."; fi
        ;;
    migrate-all)
        info "Running database migrations for all sites in instance '$INSTANCE_NAME'..."
        run_bench migrate && success "Migrations for all sites completed." || error "Migration failed."
        ;;
    migrate-site)
        shift; site_name="$1"
        if [ -z "$site_name" ]; then error "Site name required. Usage: $0 migrate-site <site_name>"; exit 1; fi
        info "Running database migrations for site '$site_name' in instance '$INSTANCE_NAME'..."
        run_bench --site "$site_name" migrate && success "Migrations for '$site_name' completed." || error "Migration failed for '$site_name'."
        ;;
    new-site)
        shift; site_name="$1"; admin_password="admin"
        if [ -z "$site_name" ]; then error "Site name required. Usage: $0 new-site <site_name>"; exit 1; fi
        if ! [[ "$site_name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
            # Simple validation allowing dots and hyphens - adjust if needed
            error "Invalid site name: '$site_name'. Should typically be domain-like (e.g., site1.localhost, myapp.test)."
            exit 1
        fi
        # Warning if it doesn't end in .localhost for typical dev setup
        if ! [[ "$site_name" =~ \.localhost$ ]]; then
             warning "Site name '$site_name' does not end with '.localhost'. Accessing it via http://$site_name:8000 might require additional host/DNS configuration."
        fi
        read -p "Enter admin password for '$site_name' [default: admin]: " admin_pw_input
        if [ -n "$admin_pw_input" ]; then admin_password="$admin_pw_input"; fi
        info "Creating new site '$site_name' with admin password '$admin_password' in instance '$INSTANCE_NAME'..."
        run_bench new-site "$site_name" --db-root-username root --mariadb-root-password "$DB_ROOT_PASSWORD" --admin-password "$admin_password" --no-mariadb-socket
        if [ $? -eq 0 ]; then
            success "Site '$site_name' created."
            info "Enabling developer mode for '$site_name'..."
            (run_bench --site "$site_name" set-config developer_mode 1 && run_bench --site "$site_name" clear-cache && success "Developer mode enabled for '$site_name'.") || error "Failed to enable dev mode for '$site_name'."
            warning "Remember to access this site:"
            warning "1. If needed, add '${Cyan}127.0.0.1 $site_name${Color_Off}' to your system's /etc/hosts file."
            warning "2. Visit ${Cyan}http://$site_name:8000${Color_Off}"
        else error "Site creation failed."; fi
        ;;
    set-default-site)
        shift; site_name="$1"
        if [ -z "$site_name" ]; then error "Site name required. Usage: $0 set-default-site <site_name>"; exit 1; fi
        info "Setting '$site_name' as the default site for instance '$INSTANCE_NAME'..."
        run_bench use "$site_name" && success "Default site set to '$site_name'." || error "Failed to set default site."
        ;;
    toggle-dev-mode)
        info "Toggling global developer mode (common_site_config.json) for instance '$INSTANCE_NAME'..."
        current_value=$(get_config_value global developer_mode)
        # Check status of get_config_value
        if [ $? -ne 0 ]; then error "Could not retrieve current developer_mode setting."; exit 1; fi

        new_value=1; status_msg="ON"; current_status="OFF"
        # Check if the retrieved value is exactly "1"
        if [[ "$current_value" == "1" ]]; then
            new_value=0; status_msg="OFF"; current_status="ON";
        fi

        info "Developer mode is currently ${current_status}."
        read -p "Set global developer mode to ${status_msg}? (y/n): " -n 1 -r; echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            run_bench set-config -g developer_mode $new_value
             if [ $? -eq 0 ]; then
                 success "Global developer mode set to: $new_value ($status_msg)"
                 info "Restart bench ('$0 dev' or '$0 restart') if it was running."
            else error "Failed to toggle developer mode."; fi
        else info "Operation cancelled."; fi
        ;;
    toggle-csrf)
        shift; site_name="$1"
        if [ -z "$site_name" ]; then error "Site name required. Usage: $0 toggle-csrf <site_name>"; exit 1; fi

        info "Toggling CSRF check setting ('ignore_csrf') for site '$site_name'..."
        current_value=$(get_config_value site "$site_name" ignore_csrf)
        # Check status of get_config_value
        if [ $? -ne 0 ]; then error "Could not retrieve CSRF setting for site '$site_name'. Does the site exist?"; exit 1; fi

        new_value=1; status_msg="ON (CSRF Disabled)"; current_status="OFF (CSRF Enabled)"
        # Check if the retrieved value is exactly "1"
        if [[ "$current_value" == "1" ]]; then
             new_value=0; status_msg="OFF (CSRF Enabled)"; current_status="ON (CSRF Disabled)";
        fi

        warning "${Bold_Red}SECURITY RISK:${Color_Off} Disabling CSRF checks makes your site vulnerable."
        info "Site '$site_name': ignore_csrf is currently ${current_status}."
        read -p "Set ignore_csrf for '$site_name' to ${status_msg}? (y/n): " -n 1 -r; echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            run_bench --site "$site_name" set-config ignore_csrf $new_value
            if [ $? -eq 0 ]; then
                success "'ignore_csrf' for '$site_name' set to: $new_value ($status_msg)"
                 info "Restart bench ('$0 dev' or '$0 restart') if it was running."
            else error "Failed to toggle CSRF setting for '$site_name'."; fi
        else info "Operation cancelled."; fi
        ;;
    get-app)
        shift; repo_url="$1"; branch_name="$2"
        if [ -z "$repo_url" ]; then error "Repository URL required. Usage: $0 get-app <repo_url> [branch_name]"; exit 1; fi
        app_name=$(basename "$repo_url" .git); branch_arg=""
        if [ -n "$branch_name" ]; then branch_arg="--branch $branch_name"; info "Getting app '$app_name' from '$repo_url' (branch: $branch_name) for instance '$INSTANCE_NAME'...";
        else info "Getting app '$app_name' from '$repo_url' (default branch) for instance '$INSTANCE_NAME'..."; fi
        run_bench get-app "$repo_url" $branch_arg && success "App '$app_name' downloaded." || error "Failed to get app '$app_name'."
        ;;
    install-app)
        shift; app_name="$1"; site_name="$2"
        if [ -z "$app_name" ]; then error "App name required. Usage: $0 install-app <app_name> <site_name>"; exit 1; fi
        if [ -z "$site_name" ]; then error "Site name required. Usage: $0 install-app <app_name> <site_name>"; exit 1; fi
        info "Installing app '$app_name' on site '$site_name' in instance '$INSTANCE_NAME'..."
        run_bench --site "$site_name" install-app "$app_name" && success "App '$app_name' installed on '$site_name'." || error "Failed to install app '$app_name' on '$site_name'."
        ;;
    uninstall-app)
        shift; app_name="$1"; site_name="$2"
        if [ -z "$app_name" ]; then error "App name required. Usage: $0 uninstall-app <app_name> <site_name>"; exit 1; fi
        if [ -z "$site_name" ]; then error "Site name required. Usage: $0 uninstall-app <app_name> <site_name>"; exit 1; fi
        warning "Uninstalling app '$app_name' from site '$site_name' in instance '$INSTANCE_NAME' may remove related data."
        read -p "Are you sure? (y/n): " -n 1 -r; echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            info "Uninstalling '$app_name' from '$site_name'..."
            run_bench --site "$site_name" uninstall-app "$app_name" && success "App '$app_name' uninstalled from '$site_name'." || error "Failed to uninstall app '$app_name' from '$site_name'."
        else info "Operation cancelled."; fi
        ;;

    *)
        echo -e "${Bold_Blue}Frappe Helper Tool for Instance: $INSTANCE_NAME ${Color_Off}"
        echo -e "${Cyan}Usage:${Color_Off} $(basename "$0") {command} [options]"
        echo
        echo -e "${Yellow}Docker Management:${Color_Off}"
        echo -e "  ${Green}start${Color_Off}             Start all containers"
        echo -e "  ${Green}stop${Color_Off}              Stop all containers"
        echo -e "  ${Green}restart${Color_Off}           Restart all containers"
        echo -e "  ${Green}status${Color_Off}            Show container status"
        echo -e "  ${Green}logs${Color_Off}              Follow Frappe container logs"
        echo -e "  ${Green}clean${Color_Off}             Stop/Remove containers and volumes (${Bold_Red}removes DB data${Color_Off})"
        echo
        echo -e "${Yellow}Bench / Site / Config Management:${Color_Off}" # Renamed Section Title
        echo -e "  ${Green}shell${Color_Off}             Open a bash shell in the Frappe container"
        echo -e "  ${Green}dev${Color_Off}               Start the Frappe development server (bench start)"
        echo -e "  ${Green}init${Color_Off}              Re-run initialization script (use with caution)"
        echo -e "  ${Green}update${Color_Off}            Update bench, Frappe framework, and all apps"
        echo -e "  ${Green}migrate-all${Color_Off}       Run database migrations for all sites"
        echo -e "  ${Green}migrate-site <site>${Color_Off} Run database migrations for a specific site"
        echo -e "  ${Green}new-site <name>${Color_Off}   Create a new site (e.g., site1.localhost)"
        echo -e "  ${Green}set-default-site <name>${Color_Off} Set the default site for bench commands (using 'bench use')" # Clarified
        echo -e "  ${Green}reset-default-site${Color_Off}  Remove explicit 'default_site' from common_site_config.json" # New
        echo -e "  ${Green}enable-dns-multitenant${Color_Off} Set 'dns_multitenant: true' in common_site_config.json" # New
        echo -e "  ${Green}disable-serve-default-site${Color_Off} Set 'serve_default_site: false' in common_site_config.json" # New
        echo -e "  ${Green}toggle-dev-mode${Color_Off}   Toggle global developer mode ON/OFF"
        echo -e "  ${Green}toggle-csrf <site>${Color_Off}  Toggle CSRF checks ON/OFF for a site (${Bold_Red}Security Risk!${Color_Off})"
        echo -e "  ${Green}setup-nginx${Color_Off}       Run 'bench setup nginx' (for production setups)" # New
        echo
        echo -e "${Yellow}App Management:${Color_Off}"
        echo -e "  ${Green}get-app <url> [branch]${Color_Off} Download app from Git repository"
        echo -e "  ${Green}install-app <app> <site>${Color_Off} Install downloaded app to a site"
        echo -e "  ${Green}uninstall-app <app> <site>${Color_Off} Uninstall app from a site"
        echo -e "  ${Green}build-app <app>${Color_Off}   Build JS/CSS assets for a specific app"
        echo
        echo -e "${Yellow}Utilities:${Color_Off}"
        echo -e "  ${Green}setup-ssh${Color_Off}         Setup SSH key inside container for Git (interactive)"
        echo -e "  ${Green}exec <cmd> [args...]${Color_Off} Execute arbitrary command inside Frappe container"
        exit 1
        ;;
esac

exit 0