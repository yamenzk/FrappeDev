# .devcontainer/Dockerfile

ARG PYTHON_TAG=3.11
FROM frappe/bench:py-${PYTHON_TAG}-latest

USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    netcat-openbsd \
    mariadb-client && \
    rm -rf /var/lib/apt/lists/*

USER frappe
