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
# docker-cli allows jobs to interact with Docker
RUN apk add --no-cache \
    bash \
    curl \
    docker-cli \
    procps \
    tzdata \
    && rm -rf /var/cache/apk/*

# Set working directory
WORKDIR /opt/cronicle

# Copy from builder
COPY --from=builder /opt/cronicle /opt/cronicle

# Create necessary directories
RUN mkdir -p data logs queue conf plugins

# Expose HTTP port
EXPOSE 3012

# Set entrypoint
ENTRYPOINT ["/opt/cronicle/bin/docker-entrypoint.sh"]

# Default command
CMD ["start"]
