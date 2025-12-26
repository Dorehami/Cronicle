# Production Deployment Guide

This guide covers deploying Cronicle to production environments, with a focus on CapRover deployment and production best practices.

## Table of Contents

- [Quick Start](#quick-start)
- [CapRover Deployment](#caprover-deployment)
- [Production Configuration](#production-configuration)
- [Security Hardening](#security-hardening)
- [Monitoring & Maintenance](#monitoring--maintenance)
- [Backup & Disaster Recovery](#backup--disaster-recovery)
- [Scaling Considerations](#scaling-considerations)

---

## Quick Start

For the impatient, here's the fastest path to production:

### Option 1: CapRover (Recommended)

```bash
# 1. Login to your CapRover server
caprover login

# 2. Deploy (from your Cronicle directory)
caprover deploy

# 3. Configure environment variables and enable HTTPS in CapRover dashboard
# 4. Access at https://your-app.your-domain.com
```

### Option 2: Docker on Any Server

```bash
# 1. Build the image
docker build -t cronicle:latest .

# 2. Run with production settings
docker run -d \
  --name cronicle \
  --restart unless-stopped \
  -p 3012:3012 \
  -e CRONICLE_base_app_url=https://cronicle.yourdomain.com \
  -e CRONICLE_secret_key=$(openssl rand -hex 32) \
  -v cronicle-data:/opt/cronicle/data \
  -v cronicle-logs:/opt/cronicle/logs \
  cronicle:latest
```

---

## CapRover Deployment

CapRover is a free, open-source PaaS that makes deploying Docker applications effortless. It's the **recommended** deployment method for Cronicle.

### Prerequisites

1. **CapRover Server**: Set up a CapRover server following [CapRover installation guide](https://caprover.com/docs/get-started.html)
2. **CapRover CLI**: Install locally with `npm install -g caprover`
3. **Domain**: A domain pointed to your CapRover server

### Step-by-Step Deployment

#### 1. Initial Setup

```bash
# Login to your CapRover instance
caprover login

# Follow the prompts:
# - CapRover URL: https://captain.your-domain.com
# - Password: your-captain-password
# - Name: a friendly name for your server
```

#### 2. Create the App

You have two options:

**Option A: Via CLI**
```bash
# From your Cronicle project directory
caprover deploy

# If this is your first deployment, you'll be prompted to:
# - Select your CapRover server
# - Enter an app name (e.g., "cronicle")
# - Branch to deploy (e.g., "main")
```

**Option B: Via Dashboard**
1. Open CapRover dashboard at `https://captain.your-domain.com`
2. Go to **Apps** → **Create a New App**
3. Enter app name: `cronicle`
4. Click **Create New App**

#### 3. Configure Environment Variables

> [!IMPORTANT]
> You **must** configure at least the `CRONICLE_base_app_url` environment variable or Cronicle may freeze on startup. See below for details.

In the CapRover dashboard, go to your app → **App Configs** → **Environment Variables** and add:

| Variable | Value | Required |
|----------|-------|----------|
| `CRONICLE_base_app_url` | `https://cronicle-app.infra.dorehami.dev` (use your actual URL) | ✅ **CRITICAL** |
| `CRONICLE_secret_key` | Generate with `openssl rand -hex 32` | ✅ |
| `CRONICLE_WebServer__http_bind_address` | `0.0.0.0` | ✅ **CRITICAL for CapRover** |
| `CRONICLE_email_from` | `cronicle@your-domain.com` | Recommended |
| `CRONICLE_smtp_hostname` | Your SMTP server | Optional |
| `CRONICLE_smtp_port` | `587` (or your SMTP port) | Optional |

> [!WARNING]
> Without `CRONICLE_base_app_url`, Cronicle will start but may not respond properly. Always set this to your actual app URL!

> [!IMPORTANT]
> Always generate a unique, strong secret key using:
> ```bash
> openssl rand -hex 32
> ```
> Never use the default or a weak key in production!

#### Advanced: SMTP Authentication with mail_options

For SMTP servers that require authentication (like Mailgun), you'll need to use a custom config override file since `mail_options` cannot be set via environment variables.

**1. Create `config-override.json` locally:**

```json
{
  "mail_options": {
    "secure": false,
    "auth": {
      "user": "your-smtp-username",
      "pass": "your-smtp-password"
    }
  }
}
```

**2. In CapRover Dashboard:**
- Go to **Apps** → **cronicle-app** → **App Configs**
- Scroll to **Persistent Directories**
- Add a new persistent directory:
  - **Path in Container**: `/opt/cronicle/conf/config-override.json`
  - **Label**: `config-override`
  
**3. Upload your config file:**
- CapRover will create a volume for this file
- You can edit it via **File Manager** in CapRover dashboard
- Or use `docker cp` to copy it to the server

**4. Redeploy** and the entrypoint will automatically merge the override config with the base config.

The merged config will include your `mail_options` for SMTP authentication!

#### 4. Enable Persistent Storage

Critical step! Without persistent storage, you'll lose all data when the container restarts.

1. Go to **App Configs** → **Persistent Directories**
2. Add these paths (one at a time):
   - Path: `/opt/cronicle/data` → Label: `data`
   - Path: `/opt/cronicle/logs` → Label: `logs`
   - Path: `/opt/cronicle/queue` → Label: `queue`
   - Path: `/opt/cronicle/plugins` → Label: `plugins`

> [!WARNING]
> Skipping this step will result in data loss on every deployment!

#### 5. Enable HTTPS

1. Go to **HTTP Settings** in your app
2. Check **Enable HTTPS**
3. Check **Force HTTPS by redirecting all HTTP traffic to HTTPS**
4. Check **Websocket Support** (optional, but recommended for some features)
5. Click **Save & Update**

#### 6. Connect Your Domain

1. In **HTTP Settings**, enter your domain: `cronicle.your-domain.com`
2. Click **Connect New Domain**
3. Click **Enable HTTPS** for your custom domain

CapRover will automatically provision an SSL certificate via Let's Encrypt!

#### 7. Deploy

If you created the app via dashboard, now deploy your code:

```bash
# From your Cronicle directory
caprover deploy
```

#### 8. Access Your Application

1. Navigate to `https://cronicle.your-domain.com`
2. Login with default credentials:
   - Username: `admin`
   - Password: `admin`
3. **Immediately change the password!** (See [Security Hardening](#security-hardening))

### CapRover Management

#### View Logs
```bash
# Via CLI
caprover logs -a cronicle -f

# Or via dashboard: Apps → cronicle → App Logs
```

#### Update/Redeploy
```bash
# Just run deploy again
caprover deploy
```

#### Rollback
CapRover keeps previous images. In the dashboard:
1. Go to **Deployment** tab
2. Select a previous version
3. Click **Deploy**

#### Monitoring
- **CPU/Memory**: Dashboard → Apps → cronicle → Monitoring
- **Health**: Automatic health checks via Docker HEALTHCHECK

### CapRover Troubleshooting

#### Permission Denied Errors

If you see errors like:
```
Error: EACCES: permission denied, open 'logs/Cronicle.log'
Error: EACCES: permission denied, mkdir 'data/_temp'
```

**This has been fixed!** The Docker container now runs as root for compatibility with CapRover's persistent directory mounting system. Container isolation provides adequate security in this context.

**If you're using an older version:**

1. **Pull the latest code**:
   ```bash
   git pull origin master
   ```

2. **Redeploy**:
   ```bash
   caprover deploy
   ```

3. **Verify** in the logs that Cronicle starts successfully:
   ```bash
   caprover logs -a cronicle -f
   ```

**Note**: The container runs as root specifically for CapRover compatibility. This is safe because:
- Container isolation provides security boundaries
- CapRover manages the infrastructure layer
- Persistent volumes mounted by CapRover require root ownership

#### Cronicle Freezes on Startup

If logs show:
```
Starting Cronicle...
Starting Cronicle daemon...
```

And then nothing else (freezes), check:

1. **Verify `CRONICLE_base_app_url` is set** in App Configs → Environment Variables:
   ```
   CRONICLE_base_app_url=https://your-app-name.your-domain.com
   ```
   Use your actual CapRover app URL!

2. **Check more verbose logs** - the latest version adds `CRONICLE_echo=1` for better logging:
   ```bash
   caprover logs -a cronicle -f --lines 100
   ```

3. **Try accessing the app** - Even if logs are quiet, the app might be working:
   ```bash
   curl https://your-app.your-domain.com/api/app/status
   ```

4. **Restart the app** after setting environment variables:
   - In CapRover dashboard → Your App → **Save & Update**

5. **If still stuck**, check the health status:
   ```bash
   # SSH into CapRover server
   docker ps | grep cronicle
   docker inspect <container-id> | grep -A 10 Health
   ```

#### "Server not found in cluster" Error

If logs show:
```
Server not found in cluster -- waiting for a master server to contact us
```

**This has been fixed!** The latest version uses a static hostname (`cronicle-master`) instead of the dynamic container hostname.

**IMPORTANT: If you already deployed previously**, you need to clear the persistent storage because it was initialized with the old hostname:

1. **In CapRover dashboard** → Your App → **App Configs** → Scroll to **Persistent Directories**

2. **Delete all persistent directories** (this will clear old data):
   - Click the ❌ next to each persistent directory
   - Confirm deletion

3. **Re-add the persistent directories**:
   - Path: `/opt/cronicle/data` → Label: `data`
   - Path: `/opt/cronicle/logs` → Label: `logs`
   - Path: `/opt/cronicle/queue` → Label: `queue`
   - Path: `/opt/cronicle/plugins` → Label: `plugins`

4. **Click "Save & Update"**

5. **Redeploy**:
   ```bash
   caprover deploy
   ```

This will reinitialize storage with the correct static hostname (`cronicle-master`).

**For fresh deployments**: Just deploy normally - the static hostname is now configured automatically.

---

## Production Configuration

### Essential Environment Variables

Configure these via environment variables (not config files) for security and flexibility:

```bash
# Application URL (must match your domain)
CRONICLE_base_app_url=https://cronicle.yourdomain.com

# Security (generate with: openssl rand -hex 32)
CRONICLE_secret_key=your_64_character_hex_string_here

# Email settings
CRONICLE_email_from=cronicle@yourdomain.com
CRONICLE_smtp_hostname=smtp.yourdomain.com
CRONICLE_smtp_port=587
CRONICLE_smtp_secure=false

# Performance tuning
CRONICLE_max_jobs=100
CRONICLE_job_memory_default=268435456  # 256MB in bytes

# Logging
CRONICLE_log_dir=/opt/cronicle/logs
CRONICLE_log_filename=cronicle.log
CRONICLE_log_archive_path=/opt/cronicle/logs/archive
```

### Advanced Configuration

For nested configuration properties, use double underscores:

```bash
# Web server settings
CRONICLE_WebServer__http_port=3012
CRONICLE_WebServer__http_timeout=360
CRONICLE_WebServer__max_connections=100

# Storage settings
CRONICLE_Storage__concurrency=4
CRONICLE_Storage__transactions=true

# Queue settings
CRONICLE_queue_dir=/opt/cronicle/queue
```

### Example Production docker-compose.yml

If not using CapRover, here's a production-ready compose file:

```yaml
services:
  cronicle:
    image: cronicle:latest
    container_name: cronicle
    restart: unless-stopped
    
    ports:
      - "3012:3012"
    
    environment:
      # Required
      - CRONICLE_base_app_url=https://cronicle.yourdomain.com
      - CRONICLE_secret_key=${CRONICLE_SECRET_KEY}  # Set in .env file
      
      # Email
      - CRONICLE_email_from=cronicle@yourdomain.com
      - CRONICLE_smtp_hostname=${SMTP_HOST}
      - CRONICLE_smtp_port=587
      
      # Performance
      - CRONICLE_max_jobs=100
      
    volumes:
      - cronicle-data:/opt/cronicle/data
      - cronicle-logs:/opt/cronicle/logs
      - cronicle-queue:/opt/cronicle/queue
      - cronicle-plugins:/opt/cronicle/plugins
    
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          memory: 512M
    
    healthcheck:
      test: ["/opt/cronicle/bin/docker-healthcheck.sh"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    
    networks:
      - cronicle

  # Optional: reverse proxy with automatic HTTPS
  nginx:
    image: nginx:alpine
    container_name: cronicle-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
    depends_on:
      - cronicle
    networks:
      - cronicle

volumes:
  cronicle-data:
  cronicle-logs:
  cronicle-queue:
  cronicle-plugins:

networks:
  cronicle:
    driver: bridge
```

---

## Security Hardening

### 1. Change Default Credentials

**Critical!** The first thing to do after deployment:

1. Login with `admin` / `admin`
2. Go to **Admin** → **Users**
3. Click on **admin** user
4. Set a strong password
5. Click **Save Changes**

### 2. Create Limited Users

Don't use the admin account for daily operations:

1. **Admin** → **Users** → **Add User**
2. Create user with appropriate privileges
3. Use this account for normal operations
4. Keep admin account for maintenance only

### 3. Secure Communications

#### Force HTTPS
```bash
# Ensure base URL uses HTTPS
CRONICLE_base_app_url=https://cronicle.yourdomain.com
```

With CapRover, enable **Force HTTPS** in HTTP Settings.

#### Secure Email
```bash
# Use TLS for email
CRONICLE_smtp_secure=true
CRONICLE_smtp_port=465
```

### 4. Network Security

#### Firewall Rules
```bash
# Only allow necessary ports
# Port 3012 (or your custom port) for Cronicle
# Port 22 for SSH
# Ports 80/443 for reverse proxy (if used)

# Example with ufw:
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

#### Use Reverse Proxy
Never expose Cronicle directly to the internet. Use:
- **CapRover** (handles this automatically)
- **Nginx** or **Traefik** as reverse proxy
- **Cloudflare** for additional DDoS protection

### 5. Regular Updates

```bash
# Rebuild with latest base image
docker build --no-cache -t cronicle:latest .

# Or with CapRover, just redeploy
caprover deploy
```

### 6. Secret Management

**Never hardcode secrets!** Use environment variables:

```bash
# Generate strong secret key
openssl rand -hex 32

# Store in environment, not in config files
CRONICLE_secret_key=your_generated_key_here
```

For CapRover, use the Environment Variables section in the dashboard.

### 7. Audit Logging

Enable comprehensive logging:

```bash
CRONICLE_debug_level=9
CRONICLE_log_archive_path=/opt/cronicle/logs/archive
```

Review logs regularly:
```bash
# Via Docker
docker logs cronicle

# Via CapRover
caprover logs -a cronicle

# Inside container
docker exec cronicle tail -f /opt/cronicle/logs/cronicle.log
```

---

## Monitoring & Maintenance

### Health Monitoring

#### Built-in Health Check

Cronicle includes a Docker health check:

```bash
# Check container health status
docker inspect cronicle | grep -A 10 Health

# Manual health check
docker exec cronicle /opt/cronicle/bin/docker-healthcheck.sh
```

#### External Monitoring

Set up external monitoring with tools like:

- **UptimeRobot**: Free HTTP(S) monitoring
- **Healthchecks.io**: Cron job monitoring
- **Prometheus + Grafana**: Advanced metrics

**Example health check endpoint**: `https://cronicle.yourdomain.com/api/app/status`

### Log Management

#### View Logs
```bash
# Real-time logs
docker logs -f cronicle

# Last 100 lines
docker logs --tail 100 cronicle

# With CapRover
caprover logs -a cronicle -f
```

#### Log Rotation

Cronicle handles log rotation automatically. Configure:

```bash
CRONICLE_log_filename=cronicle.log
CRONICLE_log_archive_path=/opt/cronicle/logs/archive
CRONICLE_log_max_archives=10
```

For Docker logs:

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

Add to `/etc/docker/daemon.json` and restart Docker.

### Performance Monitoring

#### Resource Usage

```bash
# Monitor container resources
docker stats cronicle

# Detailed metrics
docker exec cronicle top
```

#### Application Metrics

Access via web UI:
1. Login to Cronicle
2. Go to **Activity** tab
3. View job statistics, completion rates, errors

### Maintenance Tasks

#### Update Cronicle

```bash
# Pull latest code
git pull origin main

# Rebuild and redeploy
docker build -t cronicle:latest .
docker stop cronicle
docker rm cronicle
docker run -d ... cronicle:latest

# Or with CapRover
caprover deploy
```

#### Clean Up Old Jobs

Configure in Cronicle UI:
1. **Admin** → **Categories**
2. Set **Auto-Delete Jobs** to your preference (e.g., 30 days)

Or manually:
1. **Activity** tab
2. Select old jobs
3. Click **Delete**

#### Database Optimization

Cronicle uses a file-based storage system. Optimize periodically:

```bash
# Export and reimport to compact database
docker exec cronicle /opt/cronicle/bin/control.sh export /tmp/backup.txt
docker exec cronicle /opt/cronicle/bin/control.sh import /tmp/backup.txt
```

---

## Backup & Disaster Recovery

### Backup Strategy

> [!CAUTION]
> Always test your backups! A backup you haven't tested is not a backup.

#### What to Backup

1. **Data directory** (`/opt/cronicle/data`) - Essential
2. **Logs directory** (`/opt/cronicle/logs`) - Optional but recommended
3. **Plugins directory** (`/opt/cronicle/plugins`) - If you have custom plugins
4. **Environment variables** - Document your configuration

#### Automated Backup Script

```bash
#!/bin/bash
# backup-cronicle.sh

BACKUP_DIR="/backups/cronicle"
DATE=$(date +%Y%m%d-%H%M%S)
CONTAINER_NAME="cronicle"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup using Cronicle's export feature
echo "Exporting Cronicle data..."
docker exec $CONTAINER_NAME /opt/cronicle/bin/control.sh export /tmp/cronicle-export.txt --verbose

# Copy export to host
docker cp $CONTAINER_NAME:/tmp/cronicle-export.txt "$BACKUP_DIR/cronicle-export-$DATE.txt"

# Backup volumes using tar
echo "Backing up data volume..."
docker run --rm \
  -v cronicle-data:/data \
  -v "$BACKUP_DIR:/backup" \
  alpine tar czf "/backup/cronicle-data-$DATE.tar.gz" /data

echo "Backing up logs volume..."
docker run --rm \
  -v cronicle-logs:/logs \
  -v "$BACKUP_DIR:/backup" \
  alpine tar czf "/backup/cronicle-logs-$DATE.tar.gz" /logs

echo "Backing up plugins volume..."
docker run --rm \
  -v cronicle-plugins:/plugins \
  -v "$BACKUP_DIR:/backup" \
  alpine tar czf "/backup/cronicle-plugins-$DATE.tar.gz" /plugins

# Clean up old backups (keep last 7 days)
find "$BACKUP_DIR" -name "cronicle-*" -mtime +7 -delete

echo "Backup completed: $BACKUP_DIR"
```

Make executable and run:
```bash
chmod +x backup-cronicle.sh
./backup-cronicle.sh
```

#### Automated Backups with Cron

```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * /path/to/backup-cronicle.sh >> /var/log/cronicle-backup.log 2>&1
```

#### CapRover Backups

CapRover doesn't have built-in backup for persistent directories, so use the script above or:

1. **Manual backup** via CapRover CLI:
   ```bash
   # SSH into your CapRover server
   ssh root@your-server.com
   
   # Backup volumes
   docker run --rm \
     -v captain--cronicle.data:/data \
     -v /root/backups:/backup \
     alpine tar czf /backup/cronicle-data-$(date +%Y%m%d).tar.gz /data
   ```

2. **Automated** using the backup script above, scheduled on the CapRover server

### Disaster Recovery

#### Restore from Backup

**Method 1: Using Cronicle Import**

```bash
# Copy backup file to container
docker cp cronicle-export-20250101.txt cronicle:/tmp/

# Import (requires container to be stopped or in maintenance mode)
docker exec cronicle /opt/cronicle/bin/control.sh import /tmp/cronicle-export-20250101.txt
```

**Method 2: Restore Volume**

```bash
# Stop container
docker stop cronicle

# Restore data volume
docker run --rm \
  -v cronicle-data:/data \
  -v /backups/cronicle:/backup \
  alpine tar xzf /backup/cronicle-data-20250101.tar.gz -C /

# Restore other volumes similarly
docker run --rm \
  -v cronicle-logs:/logs \
  -v /backups/cronicle:/backup \
  alpine tar xzf /backup/cronicle-logs-20250101.tar.gz -C /

# Start container
docker start cronicle
```

#### Full Disaster Recovery Plan

1. **Document everything**: Keep a documented list of:
   - Environment variables
   - Domain configuration
   - DNS settings
   - SSL certificate source

2. **Test recovery quarterly**:
   ```bash
   # Simulate disaster
   docker stop cronicle
   docker volume rm cronicle-data
   
   # Restore from backup
   # ... restore commands ...
   
   # Verify
   curl https://cronicle.yourdomain.com/api/app/status
   ```

3. **Have redundancy**:
   - Store backups in multiple locations (local + cloud)
   - Keep documentation in version control
   - Test restore procedure regularly

#### Recovery Checklist

- [ ] Fresh server/CapRover instance ready
- [ ] Latest backup files accessible
- [ ] Environment variables documented
- [ ] DNS records ready to update
- [ ] SSL certificates or Let's Encrypt access
- [ ] Tested restore procedure within last 3 months

---

## Scaling Considerations

While Cronicle is designed for single-server deployments, here are considerations for scaling:

### Vertical Scaling (Recommended)

Increase resources for your single server:

**CapRover**: In dashboard → App Configs → Resources, set higher limits

**Docker Compose**:
```yaml
deploy:
  resources:
    limits:
      cpus: '4'
      memory: 4G
    reservations:
      memory: 1G
```

**Direct Docker**:
```bash
docker run -d \
  --memory=4g \
  --cpus=4 \
  # ... other options ...
  cronicle:latest
```

### Performance Tuning

#### Optimize Job Concurrency

```bash
# Maximum concurrent jobs
CRONICLE_max_jobs=200

# Default job memory limit (256MB)
CRONICLE_job_memory_default=268435456

# Default job timeout (1 hour = 3600s)
CRONICLE_job_timeout_default=3600
```

#### Database Performance

```bash
# Enable storage transactions
CRONICLE_Storage__transactions=true

# Increase concurrency
CRONICLE_Storage__concurrency=8
```

#### Web Server Tuning

```bash
# Increase max connections
CRONICLE_WebServer__max_connections=200

# Increase timeout for long-running requests
CRONICLE_WebServer__http_timeout=600
```

### Load Testing

Test your deployment under load:

```bash
# Install Apache Bench
sudo apt-get install apache2-utils

# Test web UI
ab -n 1000 -c 10 https://cronicle.yourdomain.com/

# Test API
ab -n 1000 -c 10 https://cronicle.yourdomain.com/api/app/status
```

Monitor during load:
```bash
docker stats cronicle
```

### When You've Outgrown Single Server

If you truly need distributed deployment:

1. **Horizontal scaling**: Cronicle supports multi-server mode
   - See [official multi-server documentation](https://github.com/jhuckaby/Cronicle#multi-server-cluster)
   - Requires shared storage (NFS) or database
   - More complex to set up and maintain

2. **Alternative**: Consider dedicated job orchestration platforms
   - Kubernetes CronJobs
   - Apache Airflow
   - Temporal.io

---

## Troubleshooting

### Common Production Issues

#### App Won't Start

```bash
# Check logs
caprover logs -a cronicle
# or
docker logs cronicle

# Common causes:
# 1. Port already in use
# 2. Invalid environment variable
# 3. Missing persistent storage
# 4. Insufficient memory
```

#### Can't Access UI

```bash
# Verify container is running
docker ps | grep cronicle

# Check port mapping
docker port cronicle

# Test from server
curl http://localhost:3012/api/app/status

# Test health check
docker exec cronicle /opt/cronicle/bin/docker-healthcheck.sh
```

For CapRover:
- Check HTTP Settings domain is correct
- Ensure HTTPS is enabled
- Verify DNS points to CapRover server

#### Jobs Not Running

1. **Check event configuration**:
   - Login to UI
   - Go to **Schedule** tab
   - Verify event is enabled
   - Check timing and timing settings

2. **Check logs**:
   ```bash
   docker exec cronicle tail -f /opt/cronicle/logs/cronicle.log
   ```

3. **Verify job user permissions**:
   - Container runs as `node` user (UID 1000)
   - Ensure scripts/commands are accessible

#### Email Not Working

```bash
# Test SMTP connection from container
docker exec -it cronicle sh
apk add --no-cache mailx
echo "Test" | mailx -S smtp=smtp.yourdomain.com:587 -s "Test" you@email.com
```

Common issues:
- Wrong SMTP hostname/port
- SMTP requires authentication (configure in UI)
- Firewall blocking port 587/465

#### Performance Issues

```bash
# Check resource usage
docker stats cronicle

# Check disk space
docker exec cronicle df -h

# Check job logs for slow queries/operations
docker exec cronicle tail -f /opt/cronicle/logs/cronicle.log
```

Solutions:
- Increase memory allocation
- Clean up old jobs
- Optimize job scripts
- Add more CPU cores

### Getting Help

- **Logs**: Always check logs first
  ```bash
  docker logs cronicle --tail 200
  ```

- **Community**:
  - [GitHub Issues](https://github.com/jhuckaby/Cronicle/issues)
  - [GitHub Discussions](https://github.com/jhuckaby/Cronicle/discussions)

- **Documentation**:
  - [Official Cronicle Docs](https://github.com/jhuckaby/Cronicle#documentation)
  - [CapRover Docs](https://caprover.com/docs)

---

## Additional Resources

- [Docker Documentation](Docker.md) - Detailed Docker guide
- [Configuration Reference](Configuration.md) - All configuration options
- [API Reference](APIReference.md) - For automation and integrations
- [Development Guide](Development.md) - For custom modifications

---

## Checklist: Production Deployment

Use this checklist to ensure you haven't missed anything:

### Pre-Deployment
- [ ] CapRover server is set up and accessible
- [ ] Domain DNS points to server
- [ ] Backup plan is documented
- [ ] Environment variables are prepared
- [ ] Strong secret key generated (`openssl rand -hex 32`)

### Deployment
- [ ] App deployed successfully
- [ ] Environment variables configured
- [ ] Persistent storage enabled for all directories
- [ ] HTTPS enabled and working
- [ ] Custom domain connected
- [ ] Can access UI via HTTPS

### Post-Deployment
- [ ] Default admin password changed
- [ ] Limited user account created for daily use
- [ ] Test job created and runs successfully
- [ ] Email notifications configured (if needed)
- [ ] Health checks passing
- [ ] Backup script set up and tested
- [ ] Monitoring configured
- [ ] Recovery procedure documented
- [ ] Team trained on accessing/using the system

### Ongoing
- [ ] Weekly backup verification
- [ ] Monthly backup restore test
- [ ] Quarterly security review
- [ ] Regular updates applied
- [ ] Logs reviewed periodically

---

**Questions?** Check the [troubleshooting section](#troubleshooting) or [open an issue](https://github.com/jhuckaby/Cronicle/issues).

**Happy Scheduling! 🚀**
