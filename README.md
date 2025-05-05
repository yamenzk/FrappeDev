
# Frappe Docker Development Setup

*This script streamlines the process of setting up isolated Frappe framework development instances using Docker.*
* __🤖 Disclaimer: This README, along with portions of the scripts and configuration files in this repository, were generated with AI__

## 📑 Table of Contents

- [🚀 Overview](#-overview)
- [✨ Features](#-features)
- [⚠️ Prerequisites](#️-prerequisites)
- [💻 Start Guide: Local Development](#-start-guide-local-development)
- [☁️ Start Guide: GitHub Codespaces](#️-start-guide-github-codespaces)
- [🐚 Working with the Container Shell](#-working-with-the-container-shell)
- [⚙️ Using fh.sh](#️-using-fhsh)
- [🌐 Accessing Your Frappe Instance](#-accessing-your-frappe-instance)
- [🖥️ Frontend Development with Frappe](#️-frontend-development-with-frappe)
- [📁 Directory Structure](#-directory-structure)
- [💡 Advanced Topics](#-advanced-topics)

## 🚀 Overview

FrappeDev provides a simplified approach to creating containerized Frappe development environments. It works seamlessly in both GitHub Codespaces and local development workflows, letting you get a clean, isolated Frappe environment running in minutes.

**Quick Start Links:**
- [Local Development Guide](#-start-guide-local-development)
- [GitHub Codespaces Guide](#️-start-guide-github-codespaces)

## ✨ Features

* **Fully Dockerized:** Runs Frappe and dependencies (MariaDB, Redis) in isolated containers
* **GitHub Codespaces Ready:** Seamless cloud development experience with pre-configured environment
* **Version Flexibility:** Choose any Frappe branch (Currently Supports: `version-15`, `develop`)
* **Powerful Helper Script:** Manage your instance with the included `fh.sh` 
* **Multiple Environments:** Create and manage separate Frappe instances easily
* **SSH Key Management:** Use host keys or generate new ones for Git operations

## ⚠️ Prerequisites

### For GitHub Codespaces
* A **GitHub Account** - Docker and all required tools are pre-installed

### For Local Development
* **Git** - [Installation Guide](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
* **Docker Environment**:
  
  **On Linux:**
  * **Docker Engine** - [Installation Guide](https://docs.docker.com/engine/install/#server)
  * **Docker Compose Plugin** - [Installation Guide](https://docs.docker.com/compose/install/linux/)
  
  **On Windows:**
  * **WSL 2** - [Installation Guide](https://learn.microsoft.com/en-us/windows/wsl/install)
  * **Docker Desktop for Windows** - [Installation Guide](https://docs.docker.com/desktop/install/windows-install/)

## 💻 Start Guide: Local Development

1. **Clone Repository**
   ```bash
   git clone https://github.com/yamenzk/FrappeDev.git
   cd FrappeDev
   ```

2. **Make Script Executable**
   ```bash
   chmod +x ./create_frappe_instance.sh
   ```

3. **Create Frappe Instance**
   ```bash
   ./create_frappe_instance.sh
   ```
* Fill in the prompts for instance name and Frappe branch
* Wait for the script to complete (this may take several minutes)

4. **Navigate to Instance**
   ```bash
   cd ../my-local-instance  # Replace with your instance name
   ```

5. **Start Development Server**
   ```bash
   ./fh.sh dev
   ```

6. **Access Frappe**
   * Open `http://localhost:8000` in your browser
   * Default login: `Administrator` / `admin`

## ☁️ Start Guide: GitHub Codespaces

1. **Create a Codespace**
   * Click the `<> Code` button → "Codespaces" tab
   * Click "Create codespace on main"

2. **Create Your Frappe Instance**
   ```bash
   ./create_frappe_instance.sh
   ```
* Fill in the prompts for instance name and Frappe branch
* Wait for the script to complete (this may take several minutes)

3. **Navigate to Your Instance**
   ```bash
   cd ../my-instance  # Replace with your instance name
   ```

4. **Focus VS Code on Instance (Recommended)**
   ```bash
   code .
   ```

5. **Start Development Server**
   ```bash
   ./fh.sh dev
   ```

6. **Access Frappe**
   * Find port `8000` in the VS Code "Ports" tab
   * Click the Globe icon to open in browser
   * Default login: `Administrator` / `admin`

## 🐚 Working with the Container Shell

To run bench commands directly, you need to access the container's shell environment:

```bash
./fh.sh shell
```

This command gives you a shell prompt inside the Frappe container where you can run bench commands directly (`bench --help`)


**Note:** When you're done working in the shell, type `exit` to return to your host system's terminal.

## ⚙️ Using `fh.sh`

The `fh.sh` script is included in each instance directory and provides all the tools needed to manage that specific Frappe instance.

```bash
./fh.sh <command> [options]
```

**Key Commands:**

| Category | Commands |
|----------|----------|
| **Docker** | `start`, `stop`, `restart`, `status`, `logs`, `clean` |
| **Bench/Site** | `shell`, `dev`, `init`, `update`, `migrate-all`, `migrate-site <site>`, `new-site <name>`, `set-default-site <name>` |
| **Apps** | `get-app <url> [branch]`, `install-app <app> <site>`, `uninstall-app <app> <site>`, `build-app <app>` |
| **Utilities** | `setup-ssh`, `exec <cmd>`, `toggle-dev-mode`, `toggle-csrf <site>` |
| **Multi-site** | `enable-dns-multitenant`, `disable-serve-default-site` |

Run `./fh.sh` without arguments for the complete command list with descriptions.

### Using the `clean` Tool

The `clean` command stops and deletes containers and volumes, including MariaDB data:

```bash
./fh.sh clean
```

To completely remove the entire instance directory along with all data:

```bash
./fh.sh clean -d
```

**Warning:** Using the `-d` flag will delete everything in the instance directory and cannot be undone.

## 🌐 Accessing Your Frappe Instance

* **Default Site:** Access `http://localhost:8000`
* **Custom Sites:**
  1. Add `127.0.0.1 mysite.localhost` to your hosts file
  2. Access `http://mysite.localhost:8000`

Default login credentials: `Administrator` / `admin`

## 🖥️ Frontend Development with Frappe in Docker

- Port 8080 is already exposed in the Docker configuration.
- Chokidar is included for hot reloads.

When working with frontend frameworks in your custom app:

1. Navigate to your frontend directory inside your custom app
2. When using `yarn dev`, make sure to include the `--host` flag so it works outside the container:
   ```bash
   yarn dev --host
   ```

### Frontend Setup Tool (Doppio)

To quickly set up frontend development in your Frappe app, check out [Doppio](https://github.com/NagariaHussain/doppio) - a helpful tool that streamlines setting up:
- Vue.js or React.js frontends
- Desk pages
- TypeScript support
- Frappe UI in Vue

## 📁 Directory Structure

```
<your_workspace>/
├── FrappeDev/                # Setup repository
│   ├── .devcontainer/        # Codespaces configuration
│   ├── lib/                  # Helper scripts
│   ├── templates/            # File templates
│   └── create_frappe_instance.sh # Main setup script
│
└── my-instance/              # Your Frappe instance
    ├── docker-compose.yml    # Container configuration
    ├── frappe-bench/         # Mounted source code
    ├── fh.sh      # Instance management tool
    └── scripts/
        └── init.sh           # Container initialization script
```

## 💡 Advanced Topics

### Managing Multiple Instances

#### On Local Machine
You can create multiple instances by running `create_frappe_instance.sh` with different names.

**To run multiple instances simultaneously:**
1. Edit `docker-compose.yml` in each subsequent instance 
2. Change host ports to avoid conflicts:
   * `8000:8000` → `8001:8000`
   * `3307:3306` → `3308:3306`

#### On GitHub Codespaces
For best results, create a **separate Codespace for each Frappe instance**. This provides:
* Better resource isolation
* Cleaner environments
* Avoids port conflicts

### Managing Multiple Sites (within one instance)

To handle multiple sites in a single Frappe instance:

1. **Create additional sites:**
   ```bash
   ./fh.sh new-site mysite.localhost
   ```

2. **Configure hostname resolution:**
   * Add entries to your hosts file (local development)

3. **Enable DNS multitenancy:**
   ```bash
   ./fh.sh enable-dns-multitenant
   ```

4. **Optional: Prevent default site serving:**
   ```bash
   ./fh.sh disable-serve-default-site
   ```

5. **Apply changes:**
   ```bash
   ./fh.sh restart
   ```