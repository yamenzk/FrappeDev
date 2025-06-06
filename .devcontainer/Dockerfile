# .devcontainer/Dockerfile

FROM frappe/bench:latest

USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    netcat-openbsd \
    mariadb-client && \
    rm -rf /var/lib/apt/lists/*

USER frappe