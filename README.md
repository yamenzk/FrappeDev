# FrappeDev - Quick Frappe Docker Development Setup
*(Note: This README was generated with AI)*

This script (`create_frappe_instance.sh`) streamlines the process of setting up isolated Frappe framework development instances using Docker. It generates the necessary configuration, sets up Frappe using a specified branch, and provides a powerful helper script (`frappe_helper.sh`) within each instance directory for easy management.

Stop worrying about conflicting dependencies or complex manual setups. Get a clean Frappe environment running in minutes!

## ✨ Features

* **Dockerized Environment:** Runs Frappe and its dependencies (MariaDB, Redis) in isolated Docker containers.
* **Easy Setup:** Creates a new instance with a single command or through an interactive prompt.
* **Specific Frappe Versions:** Choose the Frappe branch you want to develop against (defaults to `version-15`).
* **Helper Script Included:** Each instance comes with `frappe_helper.sh` for common tasks like starting/stopping, running bench commands, managing sites/apps, accessing logs, and more.
* **Source Code Mounting:** Mounts the `frappe-bench` directory for direct code editing on your host machine.
* **SSH Key Management:** Includes helpers for using host SSH keys or generating new ones inside the container for Git operations.
* **Clear Console Output:** Uses colored and informative messages during setup and helper script execution.

## ⚠️ Prerequisites

Before you begin, ensure you have the following installed on your system:

1.  **Docker Engine:** The script relies heavily on Docker. [Install Docker](https://docs.docker.com/engine/install/)
2.  **Docker Compose:** Used to manage the multi-container application.
    * The script automatically detects `docker compose` (v2) or `docker-compose` (v1). [Install Docker Compose](https://docs.docker.com/compose/install/)

## 🚀 Installation & Usage

You have two options to use the script:

**Option 1: Git Clone (Recommended)**

```bash
git clone [https://github.com/yamenzk/FrappeDev.git](https://github.com/yamenzk/FrappeDev.git)
cd FrappeDev
./create_frappe_instance.sh --name my-frappe-app --branch version-15
````

**Option 2: Download and Run**

1.  Download the `create_frappe_instance.sh` script.
2.  Make it executable: `chmod +x create_frappe_instance.sh`
3.  Run it:
    ```bash
    ./create_frappe_instance.sh --name my-frappe-app
    ```

-----

### Running `create_frappe_instance.sh`

This script sets up the entire instance directory and starts the initial services.

**Command-Line Arguments:**

  * `--name <instance_name>`: (Required) Specifies the name for your Frappe instance. This will also be the name of the directory created. Must contain only letters, numbers, underscores (`_`), and dashes (`-`).
  * `--branch <branch_name>`: (Optional) Specifies the Frappe framework branch to clone. Defaults to `version-15`.

**Examples:**

```bash
# Create an instance named 'my-erp' using the default branch (version-15)
./create_frappe_instance.sh --name my-erp

# Create an instance named 'bleeding-edge' using the 'develop' branch
./create_frappe_instance.sh --name bleeding-edge --branch develop
```

**Interactive Mode:**

If you run the script without the `--name` argument, it will enter interactive mode, prompting you for the instance name and branch.

```bash
./create_frappe_instance.sh
```

**What it Does:**

1.  Checks for Docker and Docker Compose.
2.  Prompts for instance name and branch if not provided.
3.  Creates a directory named `<instance_name>`.
4.  Generates `docker-compose.yml` with services (frappe, mariadb, redis\*3).
5.  Generates `scripts/init.sh` which runs *inside* the container to:
      * Wait for database/redis.
      * Setup NVM and Yarn.
      * Initialize the Frappe bench (`bench init`).
      * Configure bench settings (database/redis hosts).
      * Create the initial site (default: `dev.localhost`).
      * Enable developer mode.
      * Patch Procfile for NVM compatibility.
6.  Generates the `frappe_helper.sh` script.
7.  Starts the Docker containers using `docker compose up -d`.
8.  Installs necessary tools (`nc`, `mysql-client`, `redis-tools`) inside the `frappe` container.
9.  Sets correct ownership for the mounted `frappe-bench` volume.
10. Executes the `scripts/init.sh` script inside the `frappe` container.
11. Prints a summary with access details and helper script usage.

-----

### Using the `frappe_helper.sh` Script

Once the setup is complete, `cd` into your instance directory (`<instance_name>`) and use the `frappe_helper.sh` script to manage your development environment.

```bash
cd my-frappe-app
./frappe_helper.sh <command> [options]
```

Run `./frappe_helper.sh` without arguments to see the full list of commands.

**Key Commands:**

  * **Docker Management:**

      * `start`: Start containers.
      * `stop`: Stop containers.
      * `restart`: Restart containers.
      * `status`: Show container status.
      * `logs`: Follow logs from the `frappe` container.
      * `clean`: **Stop and remove containers AND associated data volumes (MariaDB data will be lost\!).**

  * **Bench / Site Management:**

      * `shell`: Open an interactive `bash` shell inside the `frappe` container (in the bench directory).
      * `dev`: Start the Frappe development server (`bench start`). Access via `http://localhost:8000`.
      * `init`: Re-run the internal `scripts/init.sh` (use with caution).
      * `update`: Run `bench update`.
      * `migrate-all`: Run `bench migrate` for all sites.
      * `migrate-site <site>`: Run `bench migrate` for a specific site.
      * `new-site <name.localhost>`: Create a new Frappe site (requires manual `/etc/hosts` entry).
      * `set-default-site <name>`: Set the default site used by bench commands.
      * `toggle-dev-mode`: Enable/disable global developer mode.
      * `toggle-csrf <site>`: Enable/disable CSRF checks for a site (**Security Risk\!**).

  * **App Management:**

      * `get-app <url> [branch]`: Download an app via `bench get-app`.
      * `install-app <app> <site>`: Install an app to a site (`bench --site <site> install-app <app>`).
      * `uninstall-app <app> <site>`: Uninstall an app from a site.
      * `build-app <app>`: Build JS/CSS assets for an app (`bench build --app <app>`).

  * **Utilities:**

      * `setup-ssh`: Interactively configure SSH keys inside the container (use host keys or generate new ones) for Git access.
      * `exec <cmd> [args...]`: Execute any command inside the `frappe` container.

-----

## 🌐 Accessing Your Frappe Instance

  * **Default Site:** The initial site (`dev.localhost` by default) is accessible at `http://localhost:8000`.
      * Username: `Administrator`
      * Password: `admin` (or as set during init/new-site)
  * **Custom Sites:** If you create new sites (e.g., `mysite.localhost`) using `./frappe_helper.sh new-site mysite.localhost`, you need to add an entry to your **host machine's** hosts file (`/etc/hosts` on Linux/macOS, `C:\Windows\System32\drivers\etc\hosts` on Windows):
    ```
    127.0.0.1   mysite.localhost
    ```
    Then you can access the site at `http://mysite.localhost:8000`.

## 📁 Instance Directory Structure

After running `create_frappe_instance.sh --name my-app`, you will have:

```
my-app/
├── docker-compose.yml  # Docker service definitions
├── frappe-bench/       # Mounted Frappe bench source code (edit code here!)
├── frappe_helper.sh    # Your main tool for managing this instance
└── scripts/
    └── init.sh         # Initialization script run inside the container
```

*(Note: The `mariadb-data` volume is managed by Docker and not typically visible as a directory here unless explicitly mapped)*

## 🔧 Troubleshooting

  * **Port Conflicts:** The default setup uses ports `3307` (MariaDB), `13000`, `11000`, `12000` (Redis instances), `8000-8005` (Frappe HTTP), and `9000-9005` (SocketIO) on the host. If these conflict with other services, edit the `ports:` section in `docker-compose.yml` *before* the initial `up` or after running `./frappe_helper.sh stop`.
  * **`init.sh` Fails:** Check the output of the initial setup. If `scripts/init.sh` failed:
    1.  Look for errors in the setup log.
    2.  Try running `./frappe_helper.sh logs` to see container logs.
    3.  Attempt to fix the issue (e.g., network problems, branch name typos).
    4.  You can try re-running the initialization with `./frappe_helper.sh init`. If problems persist, it might be easier to `./frappe_helper.sh clean` and run the main `create_frappe_instance.sh` again.
  * **Permission Errors:** The script attempts to set the correct ownership (`1000:1000`) for the `/workspace/frappe-bench` directory inside the container. If you encounter permission issues when bench commands try to write files, double-check the `user: "1000:1000"` setting in `docker-compose.yml` and ensure the `chown` command in `create_frappe_instance.sh` ran successfully during setup.
  * **`bench` commands fail:** Ensure you are running them via the helper script (`./frappe_helper.sh shell` then `bench ...` or `./frappe_helper.sh exec bench ...` or using specific commands like `./frappe_helper.sh migrate-all`) so they execute within the correct container environment.