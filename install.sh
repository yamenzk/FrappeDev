#!/bin/bash
# Frappe Launchpad Interactive Installer

# --- Colors for better output ---
Color_Off='\033[0m'
BGreen='\033[1;32m'
BBlue='\033[1;34m'
BYellow='\033[1;33m'
BRed='\033[1;31m'

# --- Stop on error ---
set -e

# --- Welcome Message ---
echo -e "${BBlue}===========================================${Color_Off}"
echo -e "${BBlue} Welcome to the Frappe Launchpad Installer ${Color_Off}"
echo -e "${BBlue}===========================================${Color_Off}"
echo "This script will guide you through setting up a new Frappe development instance."
echo

# --- Prerequisite Check ---
if ! command -v docker &> /dev/null || ! docker compose version &> /dev/null; then
    echo -e "${BRed}Error: 'docker' and 'docker compose' are required. Please install them and try again.${Color_Off}"
    exit 1
fi
echo -e "${BGreen}✓ Docker and Docker Compose found.${Color_Off}"

# --- Gather User Input ---
# 1. Project Name
while true; do
  read -p "Enter a name for your project (e.g., my-frappe-app): " PROJECT_NAME
  if [[ -n "$PROJECT_NAME" && "$PROJECT_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    break
  else
    echo -e "${BRed}Invalid name. Please use only letters, numbers, underscores, and dashes.${Color_Off}"
  fi
done

# 2. Frappe Branch
echo -e "\n${BYellow}Please choose a Frappe branch to install:${Color_Off}"
branches=("version-15" "develop" "version-14" "Quit")
PS3="Select a branch (enter a number): "
select branch in "${branches[@]}"; do
    case $branch in
        "version-15")
            FRAPPE_BRANCH="version-15"
            PYTHON_VERSION_FOR_BENCH="python3.11"
            break
            ;;
        "develop")
            FRAPPE_BRANCH="develop"
            PYTHON_VERSION_FOR_BENCH="python3.11"
            break
            ;;
        "version-14")
            FRAPPE_BRANCH="version-14"
            PYTHON_VERSION_FOR_BENCH="python3.10"
            break
            ;;
        "Quit")
            echo "Installation cancelled."
            exit 0
            ;;
        *) echo "Invalid option $REPLY";;
    esac
done

# 3. Site Port
read -p "Enter the main site port [default: 8000]: " SITE_PORT
SITE_PORT=${SITE_PORT:-8000}

echo
echo -e "${BGreen}--- Configuration Summary ---${Color_Off}"
echo "Project Name:             ${BYellow}${PROJECT_NAME}${Color_Off}"
echo "Frappe Branch:            ${BYellow}${FRAPPE_BRANCH}${Color_Off}"
echo "Python Version for Bench: ${BYellow}${PYTHON_VERSION_FOR_BENCH}${Color_Off}"
echo "Site will be on port:     ${BYellow}${SITE_PORT}${Color_Off}"
echo

read -p "Is this correct? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 1
fi

# --- Create .env file ---
echo -e "\n${BBlue}Creating .env file...${Color_Off}"
cat > .env <<EOF
# --- Main Instance Configuration ---
COMPOSE_PROJECT_NAME=${PROJECT_NAME}

# --- Frappe & Python Version ---
FRAPPE_BRANCH=${FRAPPE_BRANCH}
PYTHON_VERSION_FOR_BENCH=${PYTHON_VERSION_FOR_BENCH}

# --- Service Ports ---
SITE_PORT=${SITE_PORT}
SOCKETIO_PORT=$((SITE_PORT + 1000))
MARIADB_PORT=$((SITE_PORT + 1))
REDIS_CACHE_PORT=$((SITE_PORT + 5000))
REDIS_QUEUE_PORT=$((SITE_PORT + 3000))
REDIS_SOCKETIO_PORT=$((SITE_PORT + 4000))
EOF
echo -e "${BGreen}✓ .env file created successfully.${Color_Off}"

# --- Setup Process ---
echo -e "\n${BBlue}Setting up the instance. This will take several minutes...${Color_Off}"

# 1. Set permissions for helper script
echo "Step 1: Setting executable permissions for helper script..."
chmod +x fh
echo -e "${BGreen}✓ Permissions set for ./fh.${Color_Off}"

# 2. Start services
echo "Step 2: Building images and starting Docker containers..."
docker compose up -d --build
echo -e "${BGreen}✓ Docker containers are up and running.${Color_Off}"

# 3. Run one-time setup using the fh script
echo "Step 3: Running initial bench setup..."
./fh setup
echo

# --- Success Message ---
echo -e "${BGreen}=======================================${Color_Off}"
echo -e "${BGreen}🎉 Installation Complete! 🎉${Color_Off}"
echo -e "${BGreen}=======================================${Color_Off}"
echo "Your Frappe instance '${PROJECT_NAME}' is ready."
echo
echo "To start the development server, run:"
echo -e "  ${BYellow}./fh start${Color_Off}"
echo
echo "Your site will be available at:"
echo -e "  ${BYellow}http://localhost:${SITE_PORT}${Color_Off}"
echo "  (Default Login: Administrator / admin)"
echo