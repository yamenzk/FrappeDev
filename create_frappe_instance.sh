#!/bin/bash
# create_frappe_instance.sh

# --- Configuration ---
DEFAULT_BRANCH="version-15" # Default Frappe branch
DEFAULT_SITE_ON_INIT="dev.localhost" # Default site name created by init.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
TEMPLATE_DIR="${SCRIPT_DIR}/templates"

# --- Source Libraries ---
source "${LIB_DIR}/helpers.sh"
source "${LIB_DIR}/docker_utils.sh"
source "${LIB_DIR}/docker_check.sh"
source "${LIB_DIR}/input.sh"


# --- Script Start ---
echo -e "${Bold_Blue}===========================================${Color_Off}" >&2 
echo -e "${Bold_Blue} Frappe Development Instance Creator      ${Color_Off}" >&2
echo -e "${Bold_Blue}===========================================${Color_Off}" >&2

# --- Prerequisites Check ---
check_prerequisites 

# --- Get Instance Name and Branch ---
set +e
CAPTURED_OUTPUT="$(process_input "$DEFAULT_BRANCH" "$@")"
PROCESS_INPUT_EXIT_CODE=$?
if [ $PROCESS_INPUT_EXIT_CODE -ne 0 ]; then
    error "Input processing failed." #
    exit $PROCESS_INPUT_EXIT_CODE
fi

INSTANCE_NAME=$(echo "$CAPTURED_OUTPUT" | sed -n '1p')
BRANCH=$(echo "$CAPTURED_OUTPUT" | sed -n '2p')

set -e

# --- Final Validation ---
validate_input "$INSTANCE_NAME" "$BRANCH"

# --- Directory Setup ---
step 2 "Setting up Instance Directory" 
PROJECT_ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
INSTANCE_DIR="${PROJECT_ROOT_DIR}/${INSTANCE_NAME}"
info "Target directory: $INSTANCE_DIR" 

if [ -d "$INSTANCE_DIR" ]; then
    warning "Instance directory '$INSTANCE_DIR' already exists."
    warning "Continuing may overwrite existing configuration files (docker-compose.yml, scripts, helper)."
    read -p "Do you want to continue? (y/n): " -n 1 -r REPLY
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Operation cancelled by user." 
        exit 1
    fi
    info "Proceeding with existing directory." 
else
    info "Creating instance directory: $INSTANCE_DIR" 
    mkdir -p "$INSTANCE_DIR"; check_command "create instance directory '$INSTANCE_DIR'" "$DOCKER_COMPOSE_CMD"
fi

# --- Generate Configuration Files ---
step 3 "Generating Configuration Files" 

cd "$INSTANCE_DIR"; check_command "change directory to '$INSTANCE_DIR'" "$DOCKER_COMPOSE_CMD"
info "Changed working directory to $PWD" 

# 1. Generate docker-compose.yml
info "Generating docker-compose.yml..." 
cp "${TEMPLATE_DIR}/docker-compose.yml.tpl" ./docker-compose.yml; check_command "copy docker-compose template" "$DOCKER_COMPOSE_CMD"
success "docker-compose.yml generated." 

# 2. Generate scripts/init.sh
info "Generating scripts/init.sh..." 
mkdir -p scripts; check_command "create scripts directory" "$DOCKER_COMPOSE_CMD"
INIT_SCRIPT_PATH="scripts/init.sh"
cp "${TEMPLATE_DIR}/init.sh.tpl" "$INIT_SCRIPT_PATH"; check_command "copy init.sh template" "$DOCKER_COMPOSE_CMD"

sed -i.bak "s|__BRANCH_PLACEHOLDER__|$BRANCH|g" "$INIT_SCRIPT_PATH"; check_command "set branch in init.sh" "$DOCKER_COMPOSE_CMD"
sed -i.bak "s|__DEFAULT_SITE_PLACEHOLDER__|$DEFAULT_SITE_ON_INIT|g" "$INIT_SCRIPT_PATH"; check_command "set default site in init.sh" "$DOCKER_COMPOSE_CMD"
rm -f "${INIT_SCRIPT_PATH}.bak"
info "Set Frappe branch to '$BRANCH' and initial site to '$DEFAULT_SITE_ON_INIT' in init script." 

chmod +x "$INIT_SCRIPT_PATH"; check_command "make init.sh executable" "$DOCKER_COMPOSE_CMD"
success "scripts/init.sh generated and made executable." 

# 3. Generate fh.sh
info "Generating fh.sh..." 
HELPER_SCRIPT_PATH="fh.sh"
cp "${TEMPLATE_DIR}/fh.sh.tpl" "$HELPER_SCRIPT_PATH"; check_command "copy fh.sh template" "$DOCKER_COMPOSE_CMD"

sed -i.bak "s|__INSTANCE_NAME_PLACEHOLDER__|$INSTANCE_NAME|g" "$HELPER_SCRIPT_PATH"; check_command "set instance name in helper script" "$DOCKER_COMPOSE_CMD"
rm -f "${HELPER_SCRIPT_PATH}.bak"

chmod +x "$HELPER_SCRIPT_PATH"; check_command "make fh.sh executable" "$DOCKER_COMPOSE_CMD"
success "fh.sh generated and made executable." 

# --- Start Services ---
step 4 "Starting Docker Containers" 
info "Running '$DOCKER_COMPOSE_CMD pull' to ensure images are up-to-date..." 
$DOCKER_COMPOSE_CMD pull || warning "Could not pull images. Proceeding with local images if they exist."
info "Running '$DOCKER_COMPOSE_CMD up -d --remove-orphans'..." 
$DOCKER_COMPOSE_CMD up -d --remove-orphans; check_command "start Docker containers" "$DOCKER_COMPOSE_CMD"
success "Docker containers started in detached mode." 

# --- Install Tools & Initialize Frappe Instance ---
step 5 "Installing Tools & Initializing Frappe Instance" 
info "Waiting a few seconds for containers to stabilize..." 
sleep 7

info "Installing required tools inside container (as root)..." 
APT_CMD="export DEBIAN_FRONTEND=noninteractive && apt-get update -qq >/dev/null && apt-get install -y -qq --no-install-recommends netcat-openbsd mariadb-client redis-tools apt-utils > /dev/null"
$DOCKER_COMPOSE_CMD exec -T -u root frappe bash -c "$APT_CMD"
check_command "install required tools (nc, mysqladmin, redis-cli, apt-utils) in container" "$DOCKER_COMPOSE_CMD"
success "Required tools installed/verified in container." 

info "Setting ownership of /workspace/frappe-bench inside container (as root)..." 
$DOCKER_COMPOSE_CMD exec -T -u root frappe chown -R 1000:1000 /workspace/frappe-bench
check_command "set ownership of /workspace/frappe-bench" "$DOCKER_COMPOSE_CMD"
success "Ownership set for /workspace/frappe-bench." 

info "Running initialization script inside container (scripts/init.sh as user frappe)..." 
info "This process involves downloading packages and setting up the bench/site." 
info "${Yellow}This might take several minutes depending on your system and internet connection.${Color_Off}" 
$DOCKER_COMPOSE_CMD exec -T -u frappe frappe bash /workspace/scripts/init.sh
check_command "execute initialization script (scripts/init.sh)" "$DOCKER_COMPOSE_CMD"
success "Initialization script completed successfully." 

# --- Final Summary ---
step 6 "Setup Complete!"
SUMMARY_TEXT=$(cat <<EOF
${Bold_Green}Frappe instance '$INSTANCE_NAME' (Branch: $BRANCH) is ready!${Color_Off}
------------------------------------------------------
  ${Green}Instance Dir:${Color_Off} ${Cyan}$INSTANCE_DIR${Color_Off}
  ${Green}Access URL:${Color_Off}   ${Cyan}http://localhost:8000${Color_Off} (Maps to '$DEFAULT_SITE_ON_INIT')
  ${Green}Username:${Color_Off}     Administrator
  ${Green}Password:${Color_Off}     admin (for '$DEFAULT_SITE_ON_INIT')
------------------------------------------------------
Use the helper script in '$INSTANCE_DIR': ${Bold_Green}./fh.sh${Color_Off}
  Run ${Bold_Green}./fh.sh${Color_Off} without arguments to see available commands.
======================================================
${Green}Navigate to instance:${Color_Off} ${Cyan}cd ../$INSTANCE_NAME${Color_Off}
${Green}Access container shell (to access bench):${Color_Off} ${Cyan}./fh.sh shell${Color_Off}
======================================================
EOF
)
echo -e "\n$SUMMARY_TEXT"

exit 0