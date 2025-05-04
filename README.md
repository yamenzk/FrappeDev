Okay, here is the revised README incorporating all your requests for improved organization, clarity, Codespaces workflow details, multi-site handling, and the AI generation notice.

````markdown
# FrappeDev - Quick Frappe Docker Development Setup

*(Disclaimer: This README and parts of the associated scripts were generated with assistance from AI.)*

This project streamlines the process of setting up isolated Frappe framework development instances using Docker, optimized for both **GitHub Codespaces** and **local development**. It generates the necessary configuration, sets up Frappe using a specified branch, and provides a powerful helper script (`frappe_helper.sh`) within each instance directory for easy management.

Get a clean, containerized Frappe environment running in minutes!

## Table of Contents

* [✨ Features](#-features)
* [⚠️ Prerequisites](#️-prerequisites)
* [🚀 Setup Workflow](#-setup-workflow)
    * [Using GitHub Codespaces (Recommended)](#using-github-codespaces-recommended)
    * [Using Your Local Machine](#using-your-local-machine)
* [⚙️ Script Details](#️-script-details)
    * [Running `create_frappe_instance.sh`](#running-create_frappe_instancesh)
    * [Using `frappe_helper.sh`](#using-frappe_helpersh)
* [🌐 Accessing Your Frappe Instance](#-accessing-your-frappe-instance)
* [📁 Directory Structure](#-directory-structure)
* [💡 Advanced Topics](#-advanced-topics)
    * [Managing Multiple Instances (Local vs Codespaces)](#managing-multiple-instances-local-vs-codespaces)
    * [Handling Multiple Sites (within one instance)](#handling-multiple-sites-within-one-instance)
* [🔧 Troubleshooting](#-troubleshooting)

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

1.  **Git:** To clone the repository.
2.  **Docker Engine:** The script relies heavily on Docker. [Install Docker](https://docs.docker.com/engine/install/)
3.  **Docker Compose:** Used to manage the multi-container application.
    * The script automatically detects `docker compose` (v2) or `docker-compose` (v1). [Install Docker Compose](https://docs.docker.com/compose/install/)

**For GitHub Codespaces:**

1.  A **GitHub Account**. Docker and necessary tools are provided by the Codespace.

## 🚀 Setup Workflow

First, get the FrappeDev code onto your system or into your Codespace:

```bash
git clone [https://github.com/yamenzk/FrappeDev.git](https://github.com/yamenzk/FrappeDev.git)
````

Now, follow the specific steps for your chosen environment:

### Using GitHub Codespaces [(]✨New]

1.  **Create Codespace:**
      * Navigate to the cloned `FrappeDev` repository page on GitHub.
      * Click the `<> Code` button -\> "Codespaces" tab.
      * Click "Create codespace on main" (or your desired branch). GitHub sets up the environment based on `.devcontainer/devcontainer.json`.
2.  **Run Setup Script:**
      * Once the Codespace loads (VS Code in browser/local), open a terminal (Ctrl+`or Terminal > New Terminal). The working directory is`/workspaces/FrappeDev\`.
      * Run the setup script to create your first Frappe instance. Provide a name (e.g., `my-instance`). See [Running `create_frappe_instance.sh`](https://www.google.com/search?q=%23running-create_frappe_instancesh) for options.
        ```bash
        ./create_frappe_instance.sh --name my-instance
        ```
3.  **Navigate to Instance:**
      * After the script finishes, navigate to the **newly created instance directory** (it's created *alongside* `FrappeDev`):
        ```bash
        cd ../my-instance
        # You are now in /workspaces/my-instance
        ```
4.  **Open Instance Folder (Optional but Recommended):**
      * To make working with the instance easier in VS Code, open this specific instance folder:
          * In the VS Code Explorer panel (left side), right-click on the `my-instance` folder (you might need to go up one level from `FrappeDev` first).
          * Select "Open in Integrated Terminal" or use the main menu: `File` \> `Open Folder...` and select `/workspaces/my-instance`.
      * This effectively scopes your VS Code explorer and terminal to the instance directory.
5.  **Start Development Server:**
      * In a terminal located within the instance directory (`/workspaces/my-instance`), run:
        ```bash
        ./frappe_helper.sh dev
        ```
6.  **Access Frappe:** Use the "Ports" tab in VS Code. See [Accessing Your Frappe Instance](https://www.google.com/search?q=%23-accessing-your-frappe-instance).

### Using Your Local Machine

1.  **Clone Repo:**
    ```bash
    git clone [https://github.com/yamenzk/FrappeDev.git](https://github.com/yamenzk/FrappeDev.git)
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
      * Run the script from within the `FrappeDev` directory to create your instance. Provide a name (e.g., `my-local-instance`). See [Running `create_frappe_instance.sh`](https://www.google.com/search?q=%23running-create_frappe_instancesh) for options.
        ```bash
        ./create_frappe_instance.sh --name my-local-instance --branch version-14
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
7.  **Access Frappe:** Open `http://localhost:8000` in your browser. See [Accessing Your Frappe Instance](https://www.google.com/search?q=%23-accessing-your-frappe-instance).

## ⚙️ Script Details

### Running `create_frappe_instance.sh`

This script is run **from within the `FrappeDev` directory**. It orchestrates the creation of a new, independent Frappe instance directory alongside `FrappeDev`.

**Command-Line Arguments:**

  * `--name <instance_name>`: (Required) Name for your Frappe instance directory. Must contain only letters, numbers, underscores (`_`), and dashes (`-`).
  * `--branch <branch_name>`: (Optional) Frappe framework branch to clone. Defaults to `version-15`.

**Interactive Mode:**

Run `./create_frappe_instance.sh` without `--name` for interactive prompts.

**What it Does:**

1.  Checks prerequisites (Docker, Docker Compose on local).
2.  Creates the `<instance_name>/` directory alongside `FrappeDev/`.
3.  Generates `docker-compose.yml`, `scripts/init.sh`, and `frappe_helper.sh` within `<instance_name>/`.
4.  The `init.sh` script (run inside the container) initializes the Frappe bench, creates the default site (`dev.localhost`), enables developer mode, etc.
5.  Starts the Docker containers for the new instance.
6.  Installs necessary tools inside the `frappe` container.
7.  Sets volume ownership and runs the `init.sh`.
8.  Prints a summary with access details.

### Using `frappe_helper.sh`

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
      * **Custom Sites (e.g., `mysite.localhost`):**
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

## 🔧 Troubleshooting

  * **Codespaces: Container Creation Fails:** Check Codespace creation logs (View -\> Output -\> Codespaces). Look for errors like `unable to find user`. Try adjusting `image` or `remoteUser` in `.devcontainer/devcontainer.json`, commit the change, and rebuild (Command Palette -\> Codespaces: Rebuild Container).
  * **Port Conflicts (Local):** See "Managing Multiple Instances" section.
  * **`init.sh` Fails During Setup:** Check terminal output from `create_frappe_instance.sh`. `cd` into the failed instance directory (`cd ../<instance_name>`) and use `./frappe_helper.sh logs`. Try fixing the underlying issue and re-run initialization with `./frappe_helper.sh init`. If needed, clean up (`rm -rf ../<instance_name>`) and start over.
  * **Permissions:** Ensure `create_frappe_instance.sh` is executable. If bench commands fail with permission errors inside the container, verify `user: "1000:1000"` in `docker-compose.yml` and check setup logs for `chown` success.
  * **`bench` commands fail:** Always run bench commands via the helper script *from within the specific instance directory* (`./frappe_helper.sh <command>`).
