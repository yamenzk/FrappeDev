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
    echo -e "${Blue}[INIT] Initializing Frappe bench (Branch: __BRANCH_PLACEHOLDER__) at ${BENCH_PATH} (this might take a while)...${Color_Off}";
    # Run bench init from /workspace, specifying the target directory
    bench init \
      --ignore-exist \
      --skip-redis-config-generation \
      --frappe-path https://github.com/frappe/frappe \
      --frappe-branch __BRANCH_PLACEHOLDER__ \
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
SITE_NAME="__DEFAULT_SITE_PLACEHOLDER__" # Placeholder for default site name
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
NVM_LOAD_COMMAND=". /home/frappe/.nvm/nvm.sh && nvm use default > /dev/null && "

if [ -f "$PROCFILE_PATH" ]; then
    echo -e "\033[0;34m[INIT] Patching Procfile (${PROCFILE_PATH}) to source NVM before executing node...\033[0m"

    tmp_procfile=$(mktemp)

    NVM_LOAD_COMMAND_ESCAPED=$(echo "$NVM_LOAD_COMMAND" | sed 's/\//\\\//g; s/\&/\\\&/g') # Escape / and &
    if sed -E -e 's!^(socketio:|watch:)(\s*)(node\s+.*)! \1\2'"${NVM_LOAD_COMMAND_ESCAPED}"'\3!g' "$PROCFILE_PATH" > "$tmp_procfile"; then
        if [ -s "$tmp_procfile" ] && ! cmp -s "$PROCFILE_PATH" "$tmp_procfile"; then
             mv "$tmp_procfile" "$PROCFILE_PATH"; check_init_command "patch Procfile to source NVM"
             echo -e "\033[0;32m[INIT] Procfile patched successfully to source NVM.\033[0m"
        elif cmp -s "$PROCFILE_PATH" "$tmp_procfile"; then
             echo -e "\033[0;33m[INIT] Procfile already seems patched or no changes needed.\033[0m"
             rm -f "$tmp_procfile" # Clean up unchanged temp file
        else
            echo -e "\033[0;31m[INIT ERROR] Failed to create patched Procfile content (sed output empty?). Aborting.\033[0m"
            rm -f "$tmp_procfile"
            exit 1
        fi
    elif [ $? -ne 0 ]; then
        echo -e "\033[0;31m[INIT ERROR] Failed execute sed command for patching Procfile. Aborting.\033[0m"
        rm -f "$tmp_procfile"
        exit 1
    fi
else
    echo -e "\033[0;33m[INIT WARN] Procfile not found at ${PROCFILE_PATH}. Skipping patch.\033[0m"
fi


echo -e "\\n${Bold_Green}--- Frappe Initialization Complete --- ${Color_Off}"
echo -e "${Blue}To start the development server, run './frappe_helper.sh dev' on the host.${Color_Off}"
echo -e "${Blue}Your site '${SITE_NAME}' will be available at: http://localhost:8000${Color_Off}"

exit 0