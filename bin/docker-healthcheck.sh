#!/bin/bash
# Docker health check script for Cronicle
# Returns 0 if healthy, 1 if unhealthy

# Check if the process is running
if ! pgrep -f "node.*main.js" > /dev/null; then
    echo "Cronicle process not running"
    exit 1
fi

# Check if web server is responding
HTTP_PORT=${CRONICLE_WebServer__http_port:-3012}

if command -v curl > /dev/null; then
    # Use curl if available
    if ! curl -sf "http://localhost:${HTTP_PORT}/" > /dev/null; then
        echo "Web server not responding on port ${HTTP_PORT}"
        exit 1
    fi
elif command -v wget > /dev/null; then
    # Fallback to wget
    if ! wget -q -O /dev/null "http://localhost:${HTTP_PORT}/"; then
        echo "Web server not responding on port ${HTTP_PORT}"
        exit 1
    fi
else
    # No HTTP client available, just check if port is listening
    if ! netstat -ln | grep -q ":${HTTP_PORT}"; then
        echo "Port ${HTTP_PORT} not listening"
        exit 1
    fi
fi

echo "Health check passed"
exit 0
