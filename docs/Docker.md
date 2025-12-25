# Docker Guide for Cronicle

This guide covers running Cronicle in Docker for both development and production environments, including deployment to CapRover.

## Quick Start

### Using Docker Run

```bash
# Run Cronicle with default settings
docker run -d \
  --name cronicle \
  -p 3012:3012 \
  -v cronicle-data:/opt/cronicle/data \
  -v cronicle-logs:/opt/cronicle/logs \
  cronicle:latest

# Access UI at http://localhost:3012
# Default credentials: admin / admin
```

### Using Docker Compose

```bash
# Start development environment
docker compose up -d

# View logs
docker compose logs -f

# Stop
docker compose down
```

## Production Deployment

### Building the Image

```bash
# Build production image
docker build -t cronicle:latest .

# Build with specific tag
docker build -t cronicle:1.0.0 .
```

### Running in Production

```bash
docker run -d \
  --name cronicle \
  --restart unless-stopped \
  -p 3012:3012 \
  -e CRONICLE_base_app_url=https://cronicle.example.com \
  -e CRONICLE_secret_key=your_secure_random_key_here \
  -e CRONICLE_email_from=cronicle@example.com \
  -e CRONICLE_smtp_hostname=smtp.example.com \
  -v cronicle-data:/opt/cronicle/data \
  -v cronicle-logs:/opt/cronicle/logs \
  -v cronicle-queue:/opt/cronicle/queue \
  -v cronicle-plugins:/opt/cronicle/plugins \
  cronicle:latest
```

### Important Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `CRONICLE_base_app_url` | Full URL to your Cronicle instance | `http://localhost:3012` |
| `CRONICLE_secret_key` | Secret key for server authentication | `CHANGE_ME` |
| `CRONICLE_email_from` | From address for emails | `admin@localhost` |
| `CRONICLE_smtp_hostname` | SMTP server hostname | `localhost` |
| `CRONICLE_WebServer__http_port` | HTTP port | `3012` |
| `CRONICLE_foreground` | Run in foreground mode | `1` (for Docker) |

For nested configuration (e.g., `WebServer.http_port`), use double underscores: `CRONICLE_WebServer__http_port`

See [Configuration.md](Configuration.md) for all available options.

## CapRover Deployment

CapRover is the easiest way to deploy Cronicle to production.

### Prerequisites

- CapRover server set up and running
- CapRover CLI installed (`npm install -g caprover`)

### Deployment Steps

1. **Initialize CapRover app** (one-time setup):
   ```bash
   caprover login
   ```

2. **Deploy from repository**:
   ```bash
   # From your Cronicle directory
   caprover deploy
   ```

3. **Configure environment variables** in CapRover dashboard:
   - `CRONICLE_base_app_url` - Your app URL (e.g., `https://cronicle.example.com`)
   - `CRONICLE_secret_key` - Generate a secure random key
   - `CRONICLE_email_from` - Your email address
   - `CRONICLE_smtp_hostname` - Your SMTP server

4. **Enable persistent storage**:
   - In CapRover dashboard, go to your app settings
   - Add persistent directories:
     - `/opt/cronicle/data`
     - `/opt/cronicle/logs`
     - `/opt/cronicle/queue`
     - `/opt/cronicle/plugins`

5. **Enable HTTPS** in CapRover dashboard (recommended)

6. **Access your app** at the configured URL

### CapRover Tips

- The `captain-definition` file is already configured
- Default admin credentials: `admin` / `admin` (change immediately!)
- Check logs in CapRover dashboard or via CLI: `caprover logs -a your-app-name`
- To update: Just run `caprover deploy` again

## Development Setup

The `compose.yml` file is configured for local development with hot-reload:

```bash
# Start development environment
docker compose up -d

# Access container shell
docker compose exec cronicle bash

# View logs
docker compose logs -f cronicle

# Restart service
docker compose restart cronicle

# Stop and remove
docker compose down
```

### Development Features

- Source code mounted for live changes
- Debug mode enabled
- Logs visible in terminal
- Persistent volumes for data

## Volume Management

### Persistent Data

Cronicle stores data in several directories:

- `/opt/cronicle/data` - Event configurations, job history, user data
- `/opt/cronicle/logs` - Application and job logs
- `/opt/cronicle/queue` - Job queue data
- `/opt/cronicle/plugins` - Custom plugins
- `/opt/cronicle/conf` - Configuration files

### Backup

```bash
# Backup all data
docker run --rm \
  -v cronicle-data:/data \
  -v $(pwd)/backup:/backup \
  alpine tar czf /backup/cronicle-data-$(date +%Y%m%d).tar.gz /data

# Backup logs
docker run --rm \
  -v cronicle-logs:/logs \
  -v $(pwd)/backup:/backup \
  alpine tar czf /backup/cronicle-logs-$(date +%Y%m%d).tar.gz /logs
```

### Restore

```bash
# Restore data
docker run --rm \
  -v cronicle-data:/data \
  -v $(pwd)/backup:/backup \
  alpine tar xzf /backup/cronicle-data-YYYYMMDD.tar.gz -C /
```

### Using Built-in Export/Import

```bash
# Export data to file
docker exec cronicle /opt/cronicle/bin/control.sh export /opt/cronicle/data/backup.txt --verbose

# Copy export file out
docker cp cronicle:/opt/cronicle/data/backup.txt ./

# Import data (container must be stopped)
docker cp ./backup.txt cronicle:/opt/cronicle/data/
docker exec cronicle /opt/cronicle/bin/control.sh import /opt/cronicle/data/backup.txt
```

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker logs cronicle

# Check if ports are in use
docker ps | grep 3012

# Verify volumes
docker volume ls | grep cronicle
```

### Reset to Defaults

```bash
# Stop and remove container
docker stop cronicle && docker rm cronicle

# Remove volumes (WARNING: deletes all data!)
docker volume rm cronicle-data cronicle-logs cronicle-queue

# Start fresh
docker run -d --name cronicle -p 3012:3012 cronicle:latest
```

### Access Container Shell

```bash
# Access running container
docker exec -it cronicle bash

# Or start container with shell
docker run -it --rm cronicle:latest bash
```

### Check Health

```bash
# Manual health check
docker exec cronicle /opt/cronicle/bin/docker-healthcheck.sh

# View health status
docker inspect cronicle | grep -A 10 Health
```

### Common Issues

**Issue**: Permission denied errors
```bash
# Ensure proper ownership (container runs as UID 1000)
docker exec cronicle chown -R cronicle:cronicle /opt/cronicle/data /opt/cronicle/logs
```

**Issue**: Can't access UI
- Verify port mapping: `docker port cronicle`
- Check firewall settings
- Ensure container is running: `docker ps | grep cronicle`

**Issue**: Jobs not running
- Check logs: `docker logs cronicle`
- Verify storage is writable
- Check event configuration in UI

## Security Best Practices

1. **Change default credentials** immediately after first login
2. **Use strong secret key**: Generate with `openssl rand -hex 32`
3. **Run behind HTTPS** in production (CapRover does this automatically)
4. **Limit exposed ports**: Only expose 3012 (or your custom port)
5. **Regular backups**: Automate data exports
6. **Keep image updated**: Rebuild regularly for security patches
7. **Use environment variables**: Never hardcode secrets in `config.json`

## Performance Tuning

### Resource Limits

```bash
# Limit memory and CPU
docker run -d \
  --name cronicle \
  --memory=2g \
  --cpus=2 \
  -p 3012:3012 \
  cronicle:latest
```

### In docker-compose:

```yaml
services:
  cronicle:
    # ...
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          memory: 512M
```

## Advanced Configuration

### Custom Config File

```bash
# Mount custom config (not recommended, use env vars instead)
docker run -d \
  --name cronicle \
  -p 3012:3012 \
  -v $(pwd)/my-config.json:/opt/cronicle/conf/config.json \
  cronicle:latest
```

### HTTPS Setup

```bash
# Mount SSL certificates
docker run -d \
  --name cronicle \
  -p 3013:3013 \
  -e CRONICLE_WebServer__https=true \
  -e CRONICLE_WebServer__https_port=3013 \
  -v $(pwd)/ssl/cert.pem:/opt/cronicle/conf/ssl.crt \
  -v $(pwd)/ssl/key.pem:/opt/cronicle/conf/ssl.key \
  cronicle:latest
```

## Support

- [GitHub Issues](https://github.com/jhuckaby/Cronicle/issues)
- [Documentation](https://github.com/jhuckaby/Cronicle#documentation)
- [CapRover Docs](https://caprover.com/docs)
