#!/bin/bash
# lib/docker_check.sh

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"
source "$(dirname "${BASH_SOURCE[0]}")/docker_utils.sh"

check_prerequisites() {

    step 1 "Checking Prerequisites"
    local docker_found=false
    local compose_found=false

    if command -v docker &> /dev/null; then
        success "Docker found: $(docker --version)"
        docker_found=true
    else
        error "Docker command could not be found. Please install Docker."
    fi

    DOCKER_COMPOSE_CMD=$(get_docker_compose_command)
    if [[ -n "$DOCKER_COMPOSE_CMD" ]]; then
         if [[ "$DOCKER_COMPOSE_CMD" == "docker compose" ]]; then
             success "Docker Compose (v2 syntax) found."
         else
              success "Docker Compose (v1 syntax) found."
         fi
         compose_found=true
    else
        error "Neither 'docker compose' nor 'docker-compose' command found. Please install Docker Compose."
    fi

    if ! $docker_found || ! $compose_found; then
        exit 1
    fi

    export DOCKER_COMPOSE_CMD
}