# Frappe Launchpad 🚀

Plug-and-play template for spinning up isolated Frappe development environments using Docker.


## Features

-   **Fully Containerized:** All services (Frappe, MariaDB, Redis) run in Docker containers.
-   **Isolated Environments:** Create multiple, side-by-side Frappe instances without conflicts.
-   **Codespaces Ready:** Open this repository in a GitHub Codespace, and it's ready to go in minutes.
-   **Simple Configuration:** Configure your entire instance by editing a single `.env` file.
-   **Powerful Helper Script:** Use the `./fh` script for all common tasks like starting the server, running `bench` commands, and accessing the container shell.
-   **Consistent Node.js:** Uses NVM to ensure the correct Node.js version is always used.

## Getting Started (Local Development)

### Prerequisites

-   [Docker](https://www.docker.com/get-started) and Docker Compose
-   [Git](https://git-scm.com/)


### 1. Create Your Project

Clone this template repository into a new directory for your project.

```bash
git clone https://github.com/yamenzk/FrappeDev.git my-new-frappe-app
cd my-new-frappe-app
```

### 2. Configure Your Instance

Open the `.env` file and customize it. **This is the most important step.**

```ini
# .env

# 1. Give your project a unique name. This prevents Docker conflicts.
COMPOSE_PROJECT_NAME=my-new-frappe-app

# 2. Choose the Frappe version for this project.
FRAPPE_BRANCH=version-15

# 3. IMPORTANT: Assign unique ports if you plan to run multiple instances at once.
SITE_PORT=8000
SOCKETIO_PORT=9000
MARIADB_PORT=3307
# ... and so on for other ports
```

### 3. Build and Initialize

Run the following commands to build the Docker image, start the services, and initialize the Frappe bench for the first time.

```bash
# Start all services in the background
docker compose up -d --build

# Run the one-time initialization script
docker compose exec frappe bash /workspace/scripts/init.sh
```

Your Frappe instance is now ready!

### 4. Start Developing

Use the `fh` helper script for all your development tasks.

```bash
# Start the Frappe development server (and watch for file changes)
./fh start

# Access your site at http://localhost:8000 (or the SITE_PORT you configured)
# Default login: Administrator / admin

# Open a shell inside the container to use bench directly
./fh shell

# Run any bench command directly
./fh migrate
./fh --site dev.localhost install-app erpnext

# See all available commands
./fh
```

## GitHub Codespaces

1.  Fork this repository on GitHub.
2.  Click `Code` -> `Create codespace`.
3.  Wait for the Codespace to build. The `init.sh` script will run automatically.
4.  Once it's ready, open a terminal in VS Code and run `./fh start`.
5.  VS Code will automatically forward the necessary ports. Click on the "Ports" tab to find the URL for your running instance.
