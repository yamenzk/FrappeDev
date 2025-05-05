#!/bin/bash
# lib/docker_utils.sh

get_docker_compose_command() {
    if docker compose version &> /dev/null; then
        echo "docker compose"
    elif command -v docker-compose &> /dev/null; then
        echo "docker-compose"
    else
        echo "" 
    fi
}