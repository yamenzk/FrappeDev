#!/bin/bash
# lib/input.sh

source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

# Call this function like: read INSTANCE_NAME BRANCH <<< "$(process_input "$@")"
process_input() {
    local instance_name=""
    local branch=""
    local default_branch="$1"
    shift

    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --name) instance_name="$2"; shift ;;
            --branch) branch="$2"; shift ;;
            *) warning "Unknown parameter passed to input processor: $1"; exit 1 ;; # Adjusted error handling
        esac
        shift
    done

    if [ -z "$instance_name" ]; then
      info "Instance name not provided via arguments. Entering interactive mode."
      while true; do
        read -p "Enter a name for your Frappe instance (e.g., my-frappe-app): " instance_name
        if [[ -n "$instance_name" && "$instance_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
          break
        else
          error "Instance name cannot be empty and should only contain letters, numbers, underscore and dash."
        fi
      done
    fi

    if [ -z "$branch" ]; then
        read -p "Enter Frappe branch [Default: $default_branch]: " input_branch
        if [ -n "$input_branch" ]; then
            branch="$input_branch"
        else
            branch="$default_branch"
        fi
    fi
    
    echo "$instance_name"
    echo "$branch"
}

# Call this function like: validate_input "$INSTANCE_NAME" "$BRANCH"
validate_input() {
    local instance_name="$1"
    local branch="$2"
    local valid=true

    if [ -z "$instance_name" ]; then
        error "Instance name is required."
        valid=false
    elif ! [[ "$instance_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        error "Instance name '$instance_name' is invalid. Should only contain letters, numbers, underscore and dash."
        valid=false
    fi

    if [ -z "$branch" ]; then
        error "Branch name is required."
        valid=false
    fi

    if ! $valid; then
        echo "Usage: ./create_frappe_instance.sh --name <instance_name> [--branch <branch_name>]"
        echo "Or run without arguments for interactive mode."
        exit 1
    fi
    info "Using instance name: '$instance_name' and branch: '$branch'"
}