# Multi-stage Dockerfile for Cronicle
# Optimized for single-server production deployment with CapRover compatibility

# Build stage - Install dependencies
FROM node:20-alpine AS builder

WORKDIR /opt/cronicle

# Copy package files
COPY package*.json ./

# Install dependencies (use install instead of ci for flexibility)
RUN npm install --production

# Copy application files
COPY . .

# Run build script
RUN node bin/build.js dist

# Production stage
FROM node:20-alpine

LABEL maintainer="cronicle"
LABEL description="Cronicle - Multi-server task scheduler and runner"

# Install runtime dependencies
# procps provides GNU-compatible ps command needed for job monitoring
RUN apk add --no-cache \
    bash \
    curl \
    procps \
    tzdata \
    && rm -rf /var/cache/apk/*

# Set working directory
WORKDIR /opt/cronicle

# Copy from builder (node user already exists in base image as UID 1000)
COPY --from=builder --chown=node:node /opt/cronicle /opt/cronicle

# Create necessary directories and set permissions
RUN mkdir -p data logs queue conf plugins && \
    chown -R node:node data logs queue conf plugins

# Switch to non-root user
USER node

# Expose HTTP port
EXPOSE 3012

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /opt/cronicle/bin/docker-healthcheck.sh

# Set entrypoint
ENTRYPOINT ["/opt/cronicle/bin/docker-entrypoint.sh"]

# Default command
CMD ["start"]
