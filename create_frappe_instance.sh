#!/bin/bash

# create_frappe_instance.sh
# A script to create a Frappe development instance using Docker (with enhanced helper)
# Usage:
#   ./create_frappe_instance.sh --name <instance_name> [--branch <branch_name>]
#   ./create_frappe_instance.sh (interactive mode)

# --- Configuration ---
DEFAULT_BRANCH="version-15" # Default Frappe branch
DEFAULT_SITE_ON_INIT="dev.localhost" # Default site name created by init.sh

# --- Colors for Output ---
Color_Off='\033[0m'       # Text Reset
Blue='\033[0;34m'; Bold_Blue='\033[1;34m'
Green='\033[0;32m'; Bold_Green='\033[1;32m'
Yellow='\033[0;33m'; Bold_Yellow='\033[1;33m'
Red='\033[0;31m'; Bold_Red='\033[1;31m'
Cyan='\033[0;36m'


# --- Helper Echo Functions ---
info() { echo -e "${Blue}[INFO]${Color_Off} $1"; }
success() { echo -e "${Green}[SUCCESS]${Color_Off} $1"; }
warning() { echo -e "${Yellow}[WARNING]${Color_Off} $1"; }
error() { echo -e "${Red}[ERROR]${Color_Off} $1"; }
step() { echo -e "\n${Bold_Blue}>>> Step $1: $2${Color_Off}"; }

# Function to check command success and exit on failure
check_command() {
    local exit_code=$?
    local command_description="$1"
    if [ $exit_code -ne 0 ]; then
        error "Failed to $command_description (Exit Code: $exit_code). Check output above for details."
        # Attempt to show relevant logs before exiting if compose is up
        if [[ "$DOCKER_COMPOSE_CMD" ]] && $DOCKER_COMPOSE_CMD ps | grep -q 'frappe'; then
             error "Attempting to show last 50 lines of Frappe logs:"
             $DOCKER_COMPOSE_CMD logs --tail=50 frappe || true # Ignore error if logs fail
        fi
        exit $exit_code
    fi
}


# --- Script Start ---
echo -e "${Bold_Blue}===========================================${Color_Off}"
echo -e "${Bold_Blue} Frappe Development Instance Creator      ${Color_Off}"
echo -e "${Bold_Blue}===========================================${Color_Off}"


# --- Prerequisites Check ---
step 1 "Checking Prerequisites"
DOCKER_COMPOSE_CMD=""
if ! command -v docker &> /dev/null; then
    error "Docker command could not be found. Please install Docker."
    exit 1
fi
success "Docker found: $(docker --version)"

# Check for 'docker compose' (v2) first, then 'docker-compose' (v1)
if docker compose version &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker compose"
    success "Docker Compose (v2 syntax) found."
elif command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
    success "Docker Compose (v1 syntax) found."
else
    error "Neither 'docker compose' nor 'docker-compose' command found. Please install Docker Compose."
    exit 1
fi

# Don't exit on error during user input sections
set +e

# --- Initialize Variables ---
INSTANCE_NAME=""
BRANCH="$DEFAULT_BRANCH"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Argument Processing ---
info "Processing command line arguments..."
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --name) INSTANCE_NAME="$2"; shift ;;
        --branch) BRANCH="$2"; shift ;;
        *) warning "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# --- Interactive Input if Name is Missing ---
if [ -z "$INSTANCE_NAME" ]; then
  info "Instance name not provided via arguments. Entering interactive mode."
  while true; do
    # Prompt user for instance name
    read -p "Enter a name for your Frappe instance (e.g., my-frappe-app): " INSTANCE_NAME
    # Basic validation: ensure it's not empty and maybe avoid spaces/special chars if desired
    if [[ -n "$INSTANCE_NAME" && "$INSTANCE_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
      break
    else
      error "Instance name cannot be empty and should only contain letters, numbers, underscore and dash."
    fi
  done

  # Prompt user for branch, showing default
  read -p "Enter Frappe branch [Default: $BRANCH]: " input_branch
  # If user entered something, use it; otherwise, keep the default
  if [ -n "$input_branch" ]; then
    BRANCH="$input_branch"
  fi
  info "Using instance name: '$INSTANCE_NAME' and branch: '$BRANCH'"
fi

# --- Final Validation ---
if [ -z "$INSTANCE_NAME" ]; then
    error "Instance name is required."
    echo "Usage: $0 --name <instance_name> [--branch <branch_name>]"
    echo "Or run without arguments for interactive mode."
    exit 1
fi
if ! [[ "$INSTANCE_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    error "Instance name '$INSTANCE_NAME' is invalid. Should only contain letters, numbers, underscore and dash."; exit 1;
fi
if [ -z "$BRANCH" ]; then error "Branch name is required."; exit 1; fi

# Re-enable exit on error for subsequent steps
set -e

# --- Directory Setup ---
step 2 "Setting up Instance Directory"
INSTANCE_DIR="${SCRIPT_DIR}/${INSTANCE_NAME}"
info "Target directory: $INSTANCE_DIR"

if [ -d "$INSTANCE_DIR" ]; then
    warning "Instance directory '$INSTANCE_DIR' already exists."
    warning "Continuing may overwrite existing configuration files (docker-compose.yml, scripts, helper)."
    read -p "Do you want to continue? (y/n): " -n 1 -r
    echo # Move to a new line
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Operation cancelled by user."
        exit 1
    fi
    info "Proceeding with existing directory."
else
    info "Creating instance directory: $INSTANCE_DIR"
    mkdir -p "$INSTANCE_DIR"; check_command "create instance directory '$INSTANCE_DIR'"
fi

cd "$INSTANCE_DIR"; check_command "change directory to '$INSTANCE_DIR'"
info "Changed working directory to $PWD"

# --- Generate Configuration Files ---
step 3 "Generating Configuration Files"

# Create docker-compose.yml file
info "Generating docker-compose.yml..."
cat > docker-compose.yml << 'EOL'
# Docker Compose configuration for Frappe Development - Generated by script

services:
  mariadb:
    image: mariadb:10.6
    command:
      - --character-set-server=utf8mb4
      - --collation-server=utf8mb4_unicode_ci
      - --skip-character-set-client-handshake
      - --skip-innodb-read-only-compressed # Needed for 10.6
    environment:
      MYSQL_ROOT_PASSWORD: 123
      MYSQL_ROOT_HOST: '%'
    volumes:
      - mariadb-data:/var/lib/mysql
    ports:
      - "3307:3306" # Host:Container - Adjust host port if needed
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-uroot", "-p123"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis-cache:
    image: redis:alpine
    ports:
      - "13000:6379" # Host:Container - Adjust host port if needed
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis-queue:
    image: redis:alpine
    ports:
      - "11000:6379" # Host:Container - Adjust host port if needed
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis-socketio:
    image: redis:alpine
    ports:
      - "12000:6379" # Host:Container - Adjust host port if needed
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  frappe:
    image: frappe/bench:latest
    command: sleep infinity
    user: "1000:1000" # Run as frappe user (UID 1000) for permission consistency
    environment:
      - SHELL=/bin/bash
      - CHOKIDAR_USEPOLLING=true # Helps file watching in Docker
      - FRAPPE_SITE_NAME_HEADER=X-Frappe-Site-Name # Support for multi-tenant headers if needed
    volumes:
      - ./scripts:/workspace/scripts:ro # Mount initialization scripts read-only
      - ./frappe-bench:/workspace/frappe-bench # Mount bench code for development
      - ~/.ssh:/home/frappe/.ssh:ro # Optional: Mount host SSH keys read-only for Git access
    working_dir: /workspace/frappe-bench # Default dir when entering container via shell/exec
    ports:
      - "8000-8005:8000-8005" # Frappe HTTP development ports range
      - "9000-9005:9000-9005" # SocketIO development ports range
    depends_on:
      mariadb:
        condition: service_healthy
      redis-cache:
        condition: service_healthy
      redis-queue:
        condition: service_healthy
      redis-socketio:
        condition: service_healthy

volumes:
  mariadb-data: {} # Persist MariaDB data
EOL
check_command "generate docker-compose.yml"
success "docker-compose.yml generated."

# Create initialization script (scripts/init.sh) - Simplified, runs as frappe user
info "Generating scripts/init.sh..."
mkdir -p scripts; check_command "create scripts directory"
cat > scripts/init.sh << 'EOL'
#!/bin/bash
# init.sh - Runs inside the frappe container during setup - SHOULD RUN AS frappe USER

# Colors for script output inside container
Color_Off='\033[0m'; Blue='\033[0;34m'; Bold_Blue='\033[1;34m'; Green='\033[0;32m'; Bold_Green='\033[1;32m'; Yellow='\033[0;33m'; Red='\033[0;31m'

echo -e "${Bold_Blue}--- Running Frappe Initialization (as $(whoami)) --- ${Color_Off}"
set -e # Exit on any error

# Function check command success within init script
check_init_command() {
    local exit_code=$?
    local command_description="$1"
    if [ "$exit_code" != "0" ]; then
        echo -e "${Red}[INIT ERROR] Failed to $command_description (Exit Code: $exit_code). Aborting.${Color_Off}"
        exit $exit_code
    fi
}

# Check user - Should be 'frappe' (UID 1000)
if [ "$(id -u)" != "1000" ]; then echo -e "${Yellow}[INIT WARN] Running as UID $(id -u), expected 1000 (frappe). Permissions might be affected.${Color_Off}"; fi

# Setup NodeJS via NVM (assuming nvm is installed for frappe user in base image)
if [ -f "/home/frappe/.nvm/nvm.sh" ]; then
    echo -e "${Blue}[INIT] Setting up Node.js via NVM...${Color_Off}";
    source /home/frappe/.nvm/nvm.sh ; check_init_command "source NVM script"
    nvm install 18 &>/dev/null ; # Ensure Node 18 is installed
    nvm alias default 18 &>/dev/null ; check_init_command "set NVM default alias"
    nvm use default &>/dev/null ; check_init_command "use NVM default version"
    grep -qxF 'nvm use default &> /dev/null' /home/frappe/.bashrc || echo "nvm use default &> /dev/null" >> /home/frappe/.bashrc ; check_init_command "update .bashrc for NVM"
    echo -e "${Green}[INIT] Node.js setup complete ($(node -v)).${Color_Off}";

    # +++ ADD THIS SECTION +++
    echo -e "${Blue}[INIT] Installing Yarn globally using npm...${Color_Off}"
    # Ensure npm is available from the NVM setup and install yarn
    npm install -g yarn ; check_init_command "install yarn globally"
    # Optional: Verify yarn installation
    echo -e "${Green}[INIT] Yarn installed ($(yarn --version)).${Color_Off}"
    # +++ END OF ADDED SECTION +++

else
    echo -e "${Yellow}[INIT WARN] NVM not found at /home/frappe/.nvm/nvm.sh. Assuming Node.js is pre-installed.${Color_Off}";
    command -v node &>/dev/null ; check_init_command "find pre-installed node"
    echo -e "${Green}[INIT] Found Node.js ($(node -v)).${Color_Off}";
    # +++ ADD THIS SECTION HERE TOO (if supporting non-NVM case) +++
    echo -e "${Blue}[INIT] Installing Yarn globally using npm (non-NVM path)...${Color_Off}"
    npm install -g yarn ; check_init_command "install yarn globally"
    echo -e "${Green}[INIT] Yarn installed ($(yarn --version)).${Color_Off}"
    # +++ END OF ADDED SECTION +++
fi

# Required tools (nc, mysqladmin, redis-cli) should be installed by main script *before* running this

# --- Wait for Services ---
wait_for_service() {
    local name="$1"; local host="$2"; local port="$3"; local check_cmd_str="$4";
    local attempts=20; local count=0
    echo -e "${Blue}[INIT] Waiting for ${name} (${host}:${port})...${Color_Off}";
    # Check TCP port first
    while ! nc -z "${host}" "${port}"; do
        count=$((count + 1)); if [ $count -ge $attempts ]; then echo -e "${Red}[INIT ERROR] Timeout waiting for ${name} TCP port ${port}. Aborting.${Color_Off}"; exit 1; fi
        echo -e "${Yellow}[INIT] ${name} TCP port unavailable - sleeping 3s (${count}/${attempts})${Color_Off}"; sleep 3;
    done;
    echo -e "${Green}[INIT] ${name} TCP ready. Checking health...${Color_Off}"; count=0
    # Check service health using the provided command string
    until bash -c "$check_cmd_str"; do
        count=$((count + 1)); if [ $count -ge $attempts ]; then echo -e "${Red}[INIT ERROR] Timeout waiting for ${name} health check. Aborting.${Color_Off}"; exit 1; fi
        echo -e "${Yellow}[INIT] ${name} health check failed - sleeping 3s (${count}/${attempts})${Color_Off}"; sleep 3;
    done;
    echo -e "${Green}[INIT] ${name} is healthy.${Color_Off}"
}

MARIADB_CHECK_CMD="mysqladmin ping -h mariadb -u root -p123 --silent"
REDIS_CHECK_CMD_CACHE="redis-cli -h redis-cache ping | grep -q PONG"
REDIS_CHECK_CMD_QUEUE="redis-cli -h redis-queue ping | grep -q PONG"
REDIS_CHECK_CMD_SOCKETIO="redis-cli -h redis-socketio ping | grep -q PONG"

wait_for_service "MariaDB" "mariadb" "3306" "$MARIADB_CHECK_CMD"
wait_for_service "Redis Cache" "redis-cache" "6379" "$REDIS_CHECK_CMD_CACHE"
wait_for_service "Redis Queue" "redis-queue" "6379" "$REDIS_CHECK_CMD_QUEUE"
wait_for_service "Redis SocketIO" "redis-socketio" "6379" "$REDIS_CHECK_CMD_SOCKETIO"

# --- Initialize Frappe Bench ---
BENCH_PATH="/workspace/frappe-bench"
CONFIG_FILE="${BENCH_PATH}/sites/common_site_config.json" # Define path to check

cd /workspace # Ensure we are in the workspace before init

echo -e "${Blue}[INIT] Checking for existing Frappe bench in ${BENCH_PATH}...${Color_Off}"
if [ -d "${BENCH_PATH}" ] && [ -f "${BENCH_PATH}/Procfile" ]; then
    echo -e "${Yellow}[INIT] Bench '${BENCH_PATH}' already exists, skipping 'bench init'.${Color_Off}";
    # Add check: Even if bench exists, ensure the crucial config file is there
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${Red}[INIT ERROR] Bench directory exists, but '$CONFIG_FILE' is missing! Bench setup might be corrupt. Try cleaning the instance and starting over.${Color_Off}"
        exit 1 # Exit if config is missing from existing bench
    fi
else
    echo -e "${Blue}[INIT] Initializing Frappe bench (Branch: BRANCH_PLACEHOLDER) at ${BENCH_PATH} (this might take a while)...${Color_Off}";
    # Run bench init from /workspace, specifying the target directory
    bench init \
      --ignore-exist \
      --skip-redis-config-generation \
      --frappe-path https://github.com/frappe/frappe \
      --frappe-branch BRANCH_PLACEHOLDER \
      "${BENCH_PATH}" ;
    check_init_command "initialize bench"
    # Add check: Verify that init created the config file
    if [ ! -f "$CONFIG_FILE" ]; then
         echo -e "${Red}[INIT ERROR] 'bench init' completed but '$CONFIG_FILE' was not created! Check 'bench init' output for errors.${Color_Off}"
         exit 1
    fi
    echo -e "${Green}[INIT] Bench initialized.${Color_Off}";
fi

# CRITICAL: Ensure all subsequent bench commands run within the bench directory
echo -e "${Blue}[INIT] Changing directory to bench path (${BENCH_PATH})${Color_Off}"
cd "${BENCH_PATH}" ; check_init_command "change directory to bench path (${BENCH_PATH})"

# Add check: Verify current directory
echo -e "${Blue}[INIT] Verifying current directory: $(pwd) (Should be ${BENCH_PATH})${Color_Off}"
if [ "$(pwd)" != "${BENCH_PATH}" ]; then
    echo -e "${Red}[INIT ERROR] Failed to change directory to ${BENCH_PATH}! Current directory is $(pwd). Aborting.${Color_Off}"
    exit 1
fi

# --- Configure Bench ---
echo -e "${Blue}[INIT] Configuring bench database and Redis connections...${Color_Off}"
bench set-mariadb-host mariadb ; check_init_command "set mariadb host" # Now this should run in the correct CWD
bench set-redis-cache-host redis://redis-cache:6379 ; check_init_command "set redis cache host"
bench set-redis-queue-host redis://redis-queue:6379 ; check_init_command "set redis queue host"
bench set-redis-socketio-host redis://redis-socketio:6379 ; check_init_command "set redis socketio host"

# Remove redis entries from Procfile as they are handled by docker-compose
if [ -f "./Procfile" ]; then
    if grep -q 'redis' ./Procfile; then
        sed -i '/redis/d' ./Procfile ; check_init_command "remove redis from Procfile"
        echo -e "${Blue}[INIT] Removed Redis entries from Procfile.${Color_Off}";
    else
        echo -e "${Blue}[INIT] No Redis entries found in Procfile to remove.${Color_Off}";
    fi
fi;
echo -e "${Green}[INIT] Bench configuration updated.${Color_Off}"

# --- Create Site ---
SITE_NAME="DEFAULT_SITE_PLACEHOLDER" # Placeholder for default site name
ADMIN_PASS="admin"; DB_ROOT_USER="root"; DB_ROOT_PASS="123"
echo -e "${Blue}[INIT] Checking if site '${SITE_NAME}' exists...${Color_Off}"

# Check if site directory exists first
if [ -d "sites/${SITE_NAME}" ]; then
    echo -e "${Yellow}[INIT] Site '${SITE_NAME}' already exists, skipping creation.${Color_Off}"
    # Ensure dev mode is enabled for existing site
    if ! bench --site "${SITE_NAME}" get-config developer_mode 2>/dev/null | grep -q "1"; then
        echo -e "${Yellow}[INIT] Enabling developer mode for existing site '${SITE_NAME}'...${Color_Off}";
        bench --site "${SITE_NAME}" set-config developer_mode 1 ; check_init_command "enable developer mode for site ${SITE_NAME}"
        bench --site "${SITE_NAME}" clear-cache ; check_init_command "clear cache for site ${SITE_NAME}"
        echo -e "${Green}[INIT] Developer mode enabled for '${SITE_NAME}'.${Color_Off}";
    else
        echo -e "${Green}[INIT] Developer mode already enabled for '${SITE_NAME}'.${Color_Off}";
    fi
else
    echo -e "${Blue}[INIT] Creating new site '${SITE_NAME}' (Password: ${ADMIN_PASS}, this might take a while)...${Color_Off}"
    bench new-site "${SITE_NAME}" \
      --mariadb-root-password "${DB_ROOT_PASS}" \
      --admin-password "${ADMIN_PASS}" \
      --db-root-username "${DB_ROOT_USER}" \
      --no-mariadb-socket ;
    check_init_command "create new site ${SITE_NAME}"
    echo -e "${Green}[INIT] Site '${SITE_NAME}' created.${Color_Off}";

    echo -e "${Blue}[INIT] Enabling developer mode for site '${SITE_NAME}'...${Color_Off}"
    bench --site "${SITE_NAME}" set-config developer_mode 1 ; check_init_command "enable developer mode for site ${SITE_NAME}"
    bench --site "${SITE_NAME}" clear-cache ; check_init_command "clear cache for site ${SITE_NAME}"
    echo -e "${Green}[INIT] Developer mode enabled.${Color_Off}";
fi

# --- Set Default Site ---
bench use "${SITE_NAME}" ; check_init_command "set default site to ${SITE_NAME}"
echo -e "${Green}[INIT] Set '${SITE_NAME}' as default site.${Color_Off}"

# --- Install Frappe App (if needed - should be installed by init) ---
if ! bench --site "${SITE_NAME}" list-apps 2>/dev/null | grep -q "^frappe$"; then
    echo -e "${Yellow}[INIT] Frappe app not found in site '${SITE_NAME}'. Attempting install...${Color_Off}"
    bench --site "${SITE_NAME}" install-app frappe ; check_init_command "install frappe app on ${SITE_NAME}"
    echo -e "${Green}[INIT] Frappe app installed on site '${SITE_NAME}'.${Color_Off}";
fi

# Enable global developer mode (common_site_config.json)
if ! bench get-config -g developer_mode 2>/dev/null | grep -q "1"; then
    echo -e "${Blue}[INIT] Enabling global developer mode (common_site_config.json)...${Color_Off}";
    bench set-config -g developer_mode 1 ; check_init_command "enable global developer mode"
    echo -e "${Green}[INIT] Global developer mode enabled.${Color_Off}";
else
    echo -e "${Green}[INIT] Global developer mode already enabled.${Color_Off}";
fi


PROCFILE_PATH="${BENCH_PATH}/Procfile"
NVM_LOAD_COMMAND="source /home/frappe/.nvm/nvm.sh && nvm use default > /dev/null && "

if [ -f "$PROCFILE_PATH" ]; then
    echo -e "${Blue}[INIT] Patching Procfile (${PROCFILE_PATH}) for NVM compatibility...${Color_Off}"
    # Add NVM sourcing to lines starting with 'node' or specific service names
    # Use a temporary file to avoid issues with sed in-place editing complexities
    tmp_procfile=$(mktemp)
    # Add check if sed command succeeds
    if grep -qE '^(node|socketio|watch):' "$PROCFILE_PATH" && \
       sed "s|^\(socketio: \)\(node .*\)$|\1${NVM_LOAD_COMMAND}\2|g; s|^\(watch: \)\(node .*\)$|\1${NVM_LOAD_COMMAND}\2|g; s|^\(node .*\)$|${NVM_LOAD_COMMAND}\1|g" "$PROCFILE_PATH" > "$tmp_procfile"; then
        # Check if the temp file was actually created and populated
        if [ -s "$tmp_procfile" ]; then
            mv "$tmp_procfile" "$PROCFILE_PATH"; check_init_command "patch Procfile"
            echo -e "${Green}[INIT] Procfile patched successfully.${Color_Off}"
        else
            echo -e "${Red}[INIT ERROR] Failed to create patched Procfile content. Aborting.${Color_Off}"
            rm -f "$tmp_procfile" # Clean up temp file
            exit 1
        fi
    elif [ $? -ne 0 ]; then
         # Handle cases where sed might fail
        echo -e "${Red}[INIT ERROR] Failed execute sed command for patching Procfile. Aborting.${Color_Off}"
        rm -f "$tmp_procfile" # Clean up temp file
        exit 1
    else
         echo -e "${Yellow}[INIT WARN] No lines requiring NVM patching found in Procfile.${Color_Off}"
         rm -f "$tmp_procfile" # Clean up temp file
    fi
else
    echo -e "${Yellow}[INIT WARN] Procfile not found at ${PROCFILE_PATH}. Skipping patch.${Color_Off}"
fi


echo -e "\\n${Bold_Green}--- Frappe Initialization Complete --- ${Color_Off}"
echo -e "${Blue}To start the development server, run './frappe_helper.sh dev' on the host.${Color_Off}"
echo -e "${Blue}Your site '${SITE_NAME}' will be available at: http://localhost:8000${Color_Off}"

exit 0 # Explicitly exit with success
EOL
check_command "generate scripts/init.sh"
success "scripts/init.sh generated."

# Replace placeholders in the init script
sed -i "s|BRANCH_PLACEHOLDER|$BRANCH|g" scripts/init.sh; check_command "set branch in init.sh"
sed -i "s|DEFAULT_SITE_PLACEHOLDER|$DEFAULT_SITE_ON_INIT|g" scripts/init.sh; check_command "set default site in init.sh"
info "Set Frappe branch to '$BRANCH' and initial site to '$DEFAULT_SITE_ON_INIT' in init script."

# Make the init script executable
chmod +x scripts/init.sh; check_command "make init.sh executable"


# Create/Update helper script with enhanced functionality
info "Generating frappe_helper.sh with enhanced commands..."
cat > frappe_helper.sh << 'EOL'
#!/bin/bash
# Helper script for common Frappe development operations (Enhanced CLI Version)

# --- Configuration ---
BENCH_DIR="/workspace/frappe-bench"
DB_ROOT_PASSWORD="123" # Default password set in docker-compose/init.sh

# --- Colors ---
Color_Off='\033[0m'
Blue='\033[0;34m'; Bold_Blue='\033[1;34m'
Green='\033[0;32m'; Bold_Green='\033[1;32m'
Yellow='\033[0;33m'; Bold_Yellow='\033[1;33m'
Red='\033[0;31m'; Bold_Red='\033[1;31m'
Cyan='\033[0;36m'

# --- Helper Echo ---
info() { echo -e "${Blue}[INFO]${Color_Off} $1"; }
success() { echo -e "${Green}[SUCCESS]${Color_Off} $1"; }
warning() { echo -e "${Yellow}[WARNING]${Color_Off} $1"; }
error() { echo -e "${Red}[ERROR]${Color_Off} $1"; }

# --- Detect Compose Command ---
DOCKER_COMPOSE_CMD=""
if docker compose version &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
else
    error "Docker Compose command not found."
    exit 1
fi
# info "Using Docker Compose command: '$DOCKER_COMPOSE_CMD'" # Optional: uncomment for debugging

INSTANCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTANCE_NAME=$(basename "$INSTANCE_DIR")
# Ensure we are in the instance directory when running docker compose commands
cd "$INSTANCE_DIR" || exit 1

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
    $DOCKER_COMPOSE_CMD exec -T -w "$BENCH_DIR" frappe bench $site_arg get-config "$key" 2>/dev/null | tail -n 1
    return $?
}

# --- Main Command Handling ---

case "$1" in
    start)
        info "Starting Frappe containers..."
        $DOCKER_COMPOSE_CMD up -d
        success "Containers started. Access default site at http://localhost:8000"
        ;;
    stop)
        info "Stopping Frappe containers..."
        $DOCKER_COMPOSE_CMD down
        success "Containers stopped."
        ;;
    restart)
        info "Restarting Frappe containers..."
        $DOCKER_COMPOSE_CMD down
        $DOCKER_COMPOSE_CMD up -d
        success "Containers restarted. Access default site at http://localhost:8000"
        ;;
    shell)
        info "Opening shell in Frappe container (at $BENCH_DIR)..."
        $DOCKER_COMPOSE_CMD exec -it -w "$BENCH_DIR" frappe bash # Always interactive
        ;;
    dev)
        info "Starting Frappe development server inside container (bench start)..."
        run_bench start --interactive # Needs interactive
        ;;
    init)
        warning "Re-running initialization script (scripts/init.sh)."
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
        info "Showing logs from Frappe container (Ctrl+C to exit)..."
        $DOCKER_COMPOSE_CMD logs -f frappe
        ;;
    status)
        info "Container status:"
        $DOCKER_COMPOSE_CMD ps
        ;;
    build-app)
        shift # Remove 'build-app'
        if [ -z "$1" ]; then error "App name required. Usage: $0 build-app <app_name>"; exit 1; fi
        run_bench build --app "$1" && success "Assets built for app '$1'."
        ;;
    setup-ssh)
        info "Setting up SSH for Git access inside container..."

        # --- Check mount status INSIDE the container ---
        # Check involves: 1. Does dir exist? 2. If yes, can we write a temp file?
        mount_status_cmd="if [ -d /home/frappe/.ssh ]; then if touch /home/frappe/.ssh/.frappe_helper_write_test 2>/dev/null; then rm /home/frappe/.ssh/.frappe_helper_write_test; echo 'writable'; else echo 'readonly'; fi; else echo 'missing'; fi"
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
                             if ! grep -q "IdentityFile ${target_key_path}" /etc/ssh/ssh_config 2>/dev/null; then # Check host file as proxy, less reliable
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
        warning "This will stop and REMOVE all containers and data (volumes) for this instance!"
        warning "Local code in './frappe-bench' will remain."
        read -p "Are you sure? (y/n): " -n 1 -r; echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            info "Stopping containers and removing volumes..."
            $DOCKER_COMPOSE_CMD down -v
            success "Instance cleaned. All container data lost."
        else info "Operation cancelled."; fi
        ;;

    # --- NEW/MERGED COMMANDS ---
    update)
        info "Running 'bench update' (updates bench, Frappe, all installed apps)..."
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
        info "Running database migrations for all sites..."
        run_bench migrate && success "Migrations for all sites completed." || error "Migration failed."
        ;;
    migrate-site)
        shift; site_name="$1"
        if [ -z "$site_name" ]; then error "Site name required. Usage: $0 migrate-site <site_name>"; exit 1; fi
        info "Running database migrations for site '$site_name'..."
        run_bench --site "$site_name" migrate && success "Migrations for '$site_name' completed." || error "Migration failed for '$site_name'."
        ;;
    new-site)
        shift; site_name="$1"; admin_password="admin"
        if [ -z "$site_name" ]; then error "Site name required. Usage: $0 new-site <site_name>"; exit 1; fi
        if ! [[ "$site_name" =~ ^[a-zA-Z0-9_-]+\.localhost$ ]]; then error "Invalid site name: '$site_name'. Use pattern: <name>.localhost"; exit 1; fi
        read -p "Enter admin password for '$site_name' [default: admin]: " admin_pw_input
        if [ -n "$admin_pw_input" ]; then admin_password="$admin_pw_input"; fi
        info "Creating new site '$site_name' with admin password '$admin_password'..."
        run_bench new-site "$site_name" --db-root-username root --mariadb-root-password "$DB_ROOT_PASSWORD" --admin-password "$admin_password" --no-mariadb-socket
        if [ $? -eq 0 ]; then
            success "Site '$site_name' created."
            info "Enabling developer mode for '$site_name'..."
            (run_bench --site "$site_name" set-config developer_mode 1 && run_bench --site "$site_name" clear-cache && success "Developer mode enabled for '$site_name'.") || error "Failed to enable dev mode for '$site_name'."
            warning "Remember to access this site:"
            warning "1. Add '${Cyan}127.0.0.1 $site_name${Color_Off}' to your system's /etc/hosts file."
            warning "2. Visit ${Cyan}http://$site_name:8000${Color_Off}"
        else error "Site creation failed."; fi
        ;;
    set-default-site)
        shift; site_name="$1"
        if [ -z "$site_name" ]; then error "Site name required. Usage: $0 set-default-site <site_name>"; exit 1; fi
        info "Setting '$site_name' as the default site..."
        run_bench use "$site_name" && success "Default site set to '$site_name'." || error "Failed to set default site."
        ;;
    toggle-dev-mode)
        info "Toggling global developer mode (common_site_config.json)..."
        current_value=$(get_config_value global developer_mode)
        if [ $? -ne 0 ]; then error "Could not retrieve current developer_mode setting."; exit 1; fi
        new_value=1; status_msg="ON"; current_status="OFF"
        if [[ "$current_value" == "1" ]]; then new_value=0; status_msg="OFF"; current_status="ON"; fi
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
        current_value=$(get_config_value site "$site_name" ignore_csrf)
        if [ $? -ne 0 ]; then error "Could not retrieve CSRF setting for site '$site_name'. Does site exist?"; exit 1; fi
        new_value=1; status_msg="ON (CSRF Disabled)"; current_status="OFF (CSRF Enabled)"
        if [[ "$current_value" == "1" ]]; then new_value=0; status_msg="OFF (CSRF Enabled)"; current_status="ON (CSRF Disabled)"; fi
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
        if [ -n "$branch_name" ]; then branch_arg="--branch $branch_name"; info "Getting app '$app_name' from '$repo_url' (branch: $branch_name)...";
        else info "Getting app '$app_name' from '$repo_url' (default branch)..."; fi
        run_bench get-app "$repo_url" $branch_arg && success "App '$app_name' downloaded." || error "Failed to get app '$app_name'."
        ;;
    install-app)
        shift; app_name="$1"; site_name="$2"
        if [ -z "$app_name" ]; then error "App name required. Usage: $0 install-app <app_name> <site_name>"; exit 1; fi
        if [ -z "$site_name" ]; then error "Site name required. Usage: $0 install-app <app_name> <site_name>"; exit 1; fi
        info "Installing app '$app_name' on site '$site_name'..."
        run_bench --site "$site_name" install-app "$app_name" && success "App '$app_name' installed on '$site_name'." || error "Failed to install app '$app_name' on '$site_name'."
        ;;
    uninstall-app)
        shift; app_name="$1"; site_name="$2"
        if [ -z "$app_name" ]; then error "App name required. Usage: $0 uninstall-app <app_name> <site_name>"; exit 1; fi
        if [ -z "$site_name" ]; then error "Site name required. Usage: $0 uninstall-app <app_name> <site_name>"; exit 1; fi
        warning "Uninstalling app '$app_name' from site '$site_name' may remove related data."
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
        echo -e "${Yellow}Bench / Site Management:${Color_Off}"
        echo -e "  ${Green}shell${Color_Off}             Open a bash shell in the Frappe container"
        echo -e "  ${Green}dev${Color_Off}               Start the Frappe development server (bench start)"
        echo -e "  ${Green}init${Color_Off}              Re-run initialization script (use with caution)"
        echo -e "  ${Green}update${Color_Off}            Update bench, Frappe framework, and all apps"
        echo -e "  ${Green}migrate-all${Color_Off}       Run database migrations for all sites"
        echo -e "  ${Green}migrate-site <site>${Color_Off} Run database migrations for a specific site"
        echo -e "  ${Green}new-site <name>${Color_Off}   Create a new site (e.g., site1.localhost)"
        echo -e "  ${Green}set-default-site <name>${Color_Off} Set the default site for bench commands"
        echo -e "  ${Green}toggle-dev-mode${Color_Off}   Toggle global developer mode ON/OFF"
        echo -e "  ${Green}toggle-csrf <site>${Color_Off}  Toggle CSRF checks ON/OFF for a site (${Bold_Red}Security Risk!${Color_Off})"
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

EOL
check_command "generate frappe_helper.sh"
chmod +x frappe_helper.sh; check_command "make frappe_helper.sh executable"
success "frappe_helper.sh generated and made executable."

# --- Start Services ---
step 4 "Starting Docker Containers"
info "Running '$DOCKER_COMPOSE_CMD pull' to ensure images are up-to-date..."
$DOCKER_COMPOSE_CMD pull || warning "Could not pull images. Proceeding with local images if they exist." # Allow script to continue if offline
info "Running '$DOCKER_COMPOSE_CMD up -d --remove-orphans'..."
$DOCKER_COMPOSE_CMD up -d --remove-orphans; check_command "start Docker containers"
success "Docker containers started in detached mode."

# --- Install Tools & Initialize Frappe Instance ---
step 5 "Installing Tools & Initializing Frappe Instance"
info "Waiting a few seconds for containers to stabilize..."
# Give services time to fully start and pass health checks
# Increased sleep slightly, sometimes services need a moment even after healthcheck pass
# Let's reduce this back slightly now that healthchecks are reliable
sleep 7; # Adjust if needed

info "Installing required tools inside container (as root)..."
# Run apt install as root *before* running init.sh as frappe
$DOCKER_COMPOSE_CMD exec -T -u root frappe bash -c "export DEBIAN_FRONTEND=noninteractive && apt-get update -qq >/dev/null && apt-get install -y -qq --no-install-recommends netcat-openbsd mariadb-client redis-tools apt-utils > /dev/null"
check_command "install required tools (nc, mysqladmin, redis-cli, apt-utils) in container"
success "Required tools installed/verified in container."

# +++ ADD THIS SECTION +++
info "Setting ownership of /workspace/frappe-bench inside container..."
# Run chown as root to fix permissions on the mounted volume
$DOCKER_COMPOSE_CMD exec -T -u root frappe chown -R 1000:1000 /workspace/frappe-bench
check_command "set ownership of /workspace/frappe-bench"
success "Ownership set for /workspace/frappe-bench."
# +++ END OF ADDED SECTION +++

info "Running initialization script inside container (scripts/init.sh as user frappe)..."
info "This process involves downloading packages and setting up the bench/site."
info "${Yellow}This might take several minutes depending on your system and internet connection.${Color_Off}"
# Execute init.sh as frappe user, non-interactively for setup script
# Use -T to avoid pseudo-tty allocation issues in automated scripts
$DOCKER_COMPOSE_CMD exec -T -u frappe frappe bash /workspace/scripts/init.sh
check_command "execute initialization script (scripts/init.sh)" # Check exit code
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
Use the helper script in '$INSTANCE_DIR': ${Bold_Green}./frappe_helper.sh${Color_Off}
  Run ${Bold_Green}./frappe_helper.sh${Color_Off} without arguments to see available commands.
======================================================
${Yellow}Note:${Color_Off} Accessing specific *.localhost sites (e.g., site1.localhost)
      requires adding entries to your system's hosts file:
      ${Cyan}'127.0.0.1 <site_name>.localhost'${Color_Off}
======================================================
EOF
)
echo -e "\n$SUMMARY_TEXT"


exit 0