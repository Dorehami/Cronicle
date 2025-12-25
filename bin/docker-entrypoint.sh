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
    
    # Start Cronicle in foreground mode for proper signal handling
    # Docker needs the process to run in foreground to handle SIGTERM correctly
    if [ -n "$CRONICLE_foreground" ] && [ "$CRONICLE_foreground" = "1" ]; then
        # Already in foreground mode via env var
        exec node /opt/cronicle/lib/main.js
    else
        # Set foreground mode for Docker
        export CRONICLE_foreground=1
        exec node /opt/cronicle/lib/main.js
    fi
fi
