#!/bin/bash
set -e

# Docker entrypoint script for Cronicle
# Handles initialization and startup

echo "Starting Cronicle..."

# Change to app directory
cd /opt/cronicle

# Ensure directories exist for persistent storage
mkdir -p data logs queue conf plugins

# Check if this is first run (no config file)
if [ ! -f "conf/config.json" ]; then
    echo "First run detected - initializing configuration..."
    
    # Copy sample config if it doesn't exist
    if [ -f "sample_conf/config.json" ]; then
        cp -n sample_conf/config.json conf/config.json
        echo "Configuration initialized from sample"
    fi
fi

# Check if storage needs initialization (no data directory or empty)
if [ ! -d "data" ] || [ -z "$(ls -A data 2>/dev/null)" ]; then
    echo "Initializing storage..."
    
    # Run setup to initialize storage
    # This creates the initial admin user and sets up the database
    node bin/storage-cli.js setup || {
        echo "Storage initialization failed, but continuing..."
    }
    
    echo "Storage initialized successfully"
fi

# For single-server deployments, use a fixed hostname
# CapRover assigns dynamic container hostnames that change on restart
# This causes cluster mismatch issues, so we use a static hostname
if [ -z "$CRONICLE_hostname" ]; then
    export CRONICLE_hostname="cronicle-master"
    echo "Set fixed hostname to: $CRONICLE_hostname"
fi

# Set this server as the master for single-server mode
if [ -z "$CRONICLE_master_hostname" ]; then
    export CRONICLE_master_hostname="cronicle-master"
    echo "Set master hostname to: $CRONICLE_master_hostname"
fi

# Handle different startup modes
if [ "$1" = "debug" ]; then
    echo "Starting in debug mode..."
    exec node bin/debug.sh --master
elif [ "$1" = "bash" ] || [ "$1" = "sh" ]; then
    echo "Starting shell..."
    exec /bin/bash
else
    echo "Starting Cronicle daemon..."
    
    # Always start in foreground mode for Docker
    # This ensures proper signal handling and log output
    export CRONICLE_foreground=1
    export CRONICLE_echo=1
    export CRONICLE_color=0
    
    echo "Executing: node /opt/cronicle/lib/main.js"
    echo "Foreground mode: $CRONICLE_foreground"
    
    exec node /opt/cronicle/lib/main.js
fi
