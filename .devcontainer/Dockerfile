# .devcontainer/Dockerfile

# Use the official, stable 'latest' image from Frappe.
# It contains multiple versions of Python and Node.js.
FROM frappe/bench:latest

# Switch to the root user to install helper tools.
USER root

# Install essential tools for scripting and debugging.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    netcat-openbsd \
    mariadb-client && \
    rm -rf /var/lib/apt/lists/*

# Switch back to the standard, non-root 'frappe' user.
USER frappe