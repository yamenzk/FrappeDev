# FrappeDev - Quick Frappe Docker Development Setup

*(Disclaimer: This full README and parts of the associated scripts were generated with AI.)*

This project streamlines the process of setting up isolated Frappe framework development instances using Docker, optimized for both **GitHub Codespaces** and **local development**. It generates the necessary configuration, sets up Frappe using a specified branch, and provides a powerful helper script (`frappe_helper.sh`) within each instance directory for easy management.

Get a clean, containerized Frappe environment running in minutes!

## Table of Contents

* [✨ Features](#-features)
* [⚠️ Prerequisites](#️-prerequisites)
* [🚀 Setup Workflow](#-setup-workflow)
    * [Using GitHub Codespaces (Recommended)](#using-github-codespaces-recommended)
    * [Using Your Local Machine](#using-your-local-machine)
* [⚙️ Using `frappe_helper.sh`](#️-using-frappe_helpersh)
* [🌐 Accessing Your Frappe Instance](#-accessing-your-frappe-instance)
* [📁 Directory Structure](#-directory-structure)
* [💡 Advanced Topics](#-advanced-topics)
    * [Managing Multiple Instances](#managing-multiple-instances-local-vs-codespaces)
    * [Handling Multiple Sites (within one instance)](#handling-multiple-sites-within-one-instance)

## ✨ Features

* **Dockerized Environment:** Runs Frappe and its dependencies (MariaDB, Redis) in isolated Docker containers.
* **GitHub Codespaces Ready:** Includes a `.devcontainer` configuration for a seamless cloud development experience.
* **Easy Setup:** Creates new instances with a single command or through an interactive prompt.
* **Specific Frappe Versions:** Choose the Frappe branch you want to develop against (defaults to `version-15`).
* **Helper Script Included:** Each instance comes with `frappe_helper.sh` for common tasks (start/stop, bench commands, sites/apps, logs, etc.).
* **Multiple Instances (Locally):** Easily create and manage multiple separate Frappe instances on your local machine.
* **Source Code Mounting:** Mounts the `frappe-bench` directory for direct code editing.
* **SSH Key Management:** Helpers for using host SSH keys or generating new ones inside the container for Git operations.
* **Clear Console Output:** Uses colored and informative messages.

## ⚠️ Prerequisites

**For Local Development:**

1.  **Git:** Required to clone the repository. ([Install Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git))
2.  **Docker Environment:** You need a way to run Linux Docker containers, which varies by OS:
    * **On Linux:**
        * **Docker Engine:** Install the Docker daemon/service directly. ([Install Docker Engine Guide](https://docs.docker.com/engine/install/#server))
        * **Docker Compose Plugin:** Install the plugin for the modern `docker compose` (v2) command. ([Install Compose Plugin Guide](https://docs.docker.com/compose/install/linux/) - follow the "Install the Compose plugin" instructions).
    * **On Windows:**
        * **WSL 2 (Windows Subsystem for Linux):** Essential for running Linux containers efficiently on Windows. Ensure WSL 2 is installed and enabled. ([Install WSL Guide](https://learn.microsoft.com/en-us/windows/wsl/install))
        * **Docker Desktop for Windows:** This application manages Docker Engine and integrates with WSL 2. ([Install Docker Desktop Guide](https://docs.docker.com/desktop/install/windows-install/)). During installation or in its settings, ensure it's configured to use the **WSL 2 based engine**. Docker Desktop includes the required `docker compose` command.
        
*Note: The setup script automatically detects and uses either the modern `docker compose` (v2 plugin, preferred) or the older standalone `docker-compose` (v1) command if found.*

**For GitHub Codespaces:**

1.  A **GitHub Account**. Docker and necessary tools are provided by the Codespace.

## 🚀 Setup Workflow

Follow the detailed guide for your preferred environment:

  * **[Setup in GitHub Codespaces [✨New]](#using-github-codespaces-new)**
  * **[Setup on Your Local Machine](#using-your-local-machine)**


### Using GitHub Codespaces [✨New]

1.  **Create Codespace:**
      * Click the `<> Code` button -\> "Codespaces" tab.
      * Click "Create codespace on main". 
2.  **Run Setup Script:**
      * Once the Codespace loads (VS Code in browser/local), run the setup script to create your first Frappe instance.
        ```bash
        ./create_frappe_instance.sh
        ```
3.  **Navigate to Instance:**
      * After the script finishes, navigate to the **newly created instance directory** (it's created *alongside* `FrappeDev`):
        ```bash
        cd ../my-instance
        ```
4.  **Open Instance Folder (Optional but Recommended):**
      * To focus the VS Code explorer and terminal on your new instance directory, run:
        ```bash
        code .
        ```
      * This effectively scopes your VS Code explorer and terminal to the instance directory.
5.  **Start Development Server:**
      * In a terminal located within the instance directory (`/workspaces/my-instance`), run:
        ```bash
        ./frappe_helper.sh dev
        ```
6.  **Access Frappe:** Use the "Ports" tab in VS Code. See [Accessing Your Frappe Instance](#-accessing-your-frappe-instance).

### Using Your Local Machine

1.  **Clone Repo:**
    ```bash
    git clone https://github.com/yamenzk/FrappeDev.git
    ```
2.  **Navigate into Repo:**
    ```bash
    cd FrappeDev
    ```
3.  **Ensure Executable:**
    ```bash
    chmod +x ./create_frappe_instance.sh
    ```
4.  **Run Setup Script:**
      * Run the script from within the `FrappeDev` directory to create your instance. 
        ```bash
        ./create_frappe_instance.sh
        ```
5.  **Navigate to Instance:**
      * After the script finishes, navigate to the **newly created instance directory** (created alongside `FrappeDev`):
        ```bash
        cd ../my-local-instance
        # Example: If FrappeDev is in /home/user/projects/, you are now in /home/user/projects/my-local-instance/
        ```
6.  **Start Development Server:**
      * In the terminal within the instance directory, run:
        ```bash
        ./frappe_helper.sh dev
        ```
7.  **Access Frappe:** Open `http://localhost:8000` in your browser. See [Accessing Your Frappe Instance](#-accessing-your-frappe-instance).

## ⚙️ Using `frappe_helper.sh`

This script resides **inside each `<instance_name>` directory** and is used to manage that specific instance. Always run it from within the target instance directory.

```bash
cd ../my-instance # Navigate to the instance directory first!
./frappe_helper.sh <command> [options]
```

Run `./frappe_helper.sh` without arguments for the full command list.

**Key Commands:**

  * **Docker:** `start`, `stop`, `restart`, `status`, `logs`, `clean` (removes containers *and data* for this instance).
  * **Bench/Site:** `shell`, `dev`, `init`, `update`, `migrate-all`, `migrate-site <site>`, `new-site <name.localhost>`, `set-default-site <name>`, `toggle-dev-mode`, `toggle-csrf <site>`.
  * **Apps:** `get-app <url> [branch]`, `install-app <app> <site>`, `uninstall-app <app> <site>`, `build-app <app>`.
  * **Utilities:** `setup-ssh`, `exec <cmd> [args...]`.
  * **Multi-site:** `enable-dns-multitenant`, `disable-serve-default-site`.

*(Refer to the script's help output for detailed descriptions)*

## 🌐 Accessing Your Frappe Instance

  * **In GitHub Codespaces:**

    1.  Run `./frappe_helper.sh dev` inside the instance directory.
    2.  Go to the **"Ports"** tab in VS Code.
    3.  Find port `8000` and click the **Globe icon (Open in Browser)**.

    <!-- end list -->

      * Login: `Administrator` / `admin` (default)

  * **On Your Local Machine:**

      * **Default Site (`dev.localhost`):** Access `http://localhost:8000`.
          * Login: `Administrator` / `admin` (default)
      * **Additional Custom Sites (e.g., `mysite.localhost`):**
        1.  Add `127.0.0.1 mysite.localhost` to your **host machine's** hosts file (`/etc/hosts` or `C:\Windows\System32\drivers\etc\hosts`).
        2.  Access `http://mysite.localhost:8000`.

## 📁 Directory Structure

After cloning `FrappeDev` and creating an instance named `my-app`:

```
<your_workspace>/
├── FrappeDev/                # Cloned repository - contains setup logic
│   ├── .devcontainer/        # Codespaces configuration
│   │   └── devcontainer.json
│   ├── lib/                  # Helper scripts used by setup
│   ├── templates/            # Templates for generated files
│   └── create_frappe_instance.sh # The main setup script
│
└── my-app/                   # << Generated instance directory >>
    ├── docker-compose.yml    # Docker service definitions for this instance
    ├── frappe-bench/         # Mounted Frappe bench source code (edit code here!)
    ├── frappe_helper.sh      # Your main tool for managing *this* instance
    └── scripts/
        └── init.sh           # Initialization script run inside the container
```

## 💡 Advanced Topics

### Managing Multiple Instances (Local vs Codespaces)

  * **Local Machine:** You can create multiple independent instances by running `create_frappe_instance.sh` (from `FrappeDev/`) multiple times with different names. Each will get its own directory alongside `FrappeDev/`.
      * **❗ Port Conflicts:** To run multiple instances *simultaneously* locally, you **must** edit the `docker-compose.yml` file in the second (and subsequent) instance directories *before* starting them (`./frappe_helper.sh start`). Change the host-side ports (left side of the colon `:`) in the `ports:` sections to unused values (e.g., change `8000:8000` to `8001:8000`, `3307:3306` to `3308:3306`, etc.).
  * **GitHub Codespaces:** While technically possible to create multiple instance directories within one Codespace, it's **strongly recommended to create a separate Codespace for each distinct project or Frappe instance**. This provides better resource isolation, avoids potential port/configuration headaches, and keeps environments clean.

### Handling Multiple Sites (within one instance)

If you use `./frappe_helper.sh new-site <sitename>` to create additional sites *within a single Frappe instance*:

1.  **Hosts File:** You still need to add entries for each site name to your hosts file (local machine) or rely on Codespaces port forwarding if applicable (though accessing specific hostnames via the forwarded port might require browser plugins or further configuration).
2.  **DNS Multitenancy:** Frappe/Bench needs to know how to handle requests for different hostnames. You may need to enable DNS-based multitenancy:
      * `cd` into the instance directory.
      * Run `./frappe_helper.sh enable-dns-multitenant`.
3.  **Serve Default Site:** Sometimes, especially with DNS multitenancy, you might want to prevent Bench from serving the default site if no hostname matches.
      * Run `./frappe_helper.sh disable-serve-default-site`.
4.  **Restart Bench:** After changing these settings, restart the bench process for them to take effect:
      * If using `dev`: `./frappe_helper.sh stop` (if running) then `./frappe_helper.sh dev`.
      * Alternatively: `./frappe_helper.sh restart`.