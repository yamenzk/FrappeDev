# FrappeDev 🚀

Rapid, Docker-based development environment for Frappe.

> **Note:** This entire readme is AI generated.

## Prerequisites

-   [Docker](https://www.docker.com/get-started) & Docker Compose
-   [Git](https://git-scm.com/)

## Quick Install

Use the interactive installer to set up a new instance in minutes.

```bash
# 1. Clone the repository
git clone https://github.com/yamenzk/FrappeDev.git my-frappe-app

# 2. Enter the directory and make the installer executable
cd my-frappe-app && chmod +x install.sh

# 3. Run the interactive installer
./install.sh
```

Follow the on-screen prompts to name your project and choose a version. The script will handle the rest. The initial setup will take several minutes to download and configure the bench.

## Daily Development

All commands are run using the `./fh` helper script.

#### Start the Server

This is the most common command you will use.

```bash
./fh start
```

-   Access your site at `http://localhost:<PORT>` (the port you chose during installation).
-   Default Login: `Administrator` / `admin`

#### Using Bench Commands

Pass any `bench` command directly to the helper. It will be executed inside the container.

```bash
# Run database migrations
./fh migrate

# Get a new app
./fh get-app https://github.com/frappe/erpnext

# Install an app on your site
./fh --site dev.localhost install-app erpnext
```

#### Open a Container Shell

This command is your direct access to the Frappe container's environment.

```bash
./fh shell
```

This gives you a full, interactive `bash` terminal inside the `frappe` container, landing you in the `/workspace/frappe-bench` directory. It is essential for:
*   Running multiple `bench` commands in a row without typing `./fh` each time.
*   Debugging file permissions and inspecting the container's environment.
*   Using other tools like `git` or `pip` directly inside the container.

Type `exit` to return to your local machine's terminal.

## Full Cleanup

To completely and **permanently delete** all containers, data, and volumes for this instance:

```bash
# ⚠️ This is irreversible!
./fh clean
```