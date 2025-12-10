# Enterprise Backup System Guide

## 🎯 Overview

Professional enterprise-grade backup solution with:
- ✅ Pre-flight disk space checks
- ✅ Size estimation before backup
- ✅ Atomic operations (temp → rename)
- ✅ Compression with verification
- ✅ Multi-tier retention (daily/weekly/monthly)
- ✅ Integrity checks
- ✅ Lock mechanism (prevent concurrent runs)
- ✅ Alert notifications

## 📋 What Gets Backed Up

### 1. Application Source Code
- **Location:** `/opt/json2excel/app/`
- **Excludes:** `node_modules`, `.next`, logs, git
- **Compression:** tar.gz
- **Estimated Size:** ~1.4 MB compressed

### 2. Docker Image
- **Image:** `json2excel-json2excel-app:latest`
- **Format:** tar.gz
- **Estimated Size:** ~47 MB compressed

### 3. Redis Data
- **Method:** Redis SAVE command
- **Format:** RDB dump
- **Estimated Size:** ~88 bytes (minimal data)

### 4. Configuration Files
- **Includes:** `config/`, `docker-compose.yml`, `Dockerfile`, `.env.production`
- **Format:** tar.gz
- **Estimated Size:** ~6 KB

### 5. User Uploads (if exists)
- **Location:** `/var/lib/json2excel/uploads/`
- **Format:** tar.gz
- **Estimated Size:** Varies

## 🔧 Installation

### Script Installation

```bash
# Copy script
scp enterprise-backup.sh root@31.56.214.200:/usr/local/bin/

# Set permissions
ssh root@31.56.214.200 "chmod +x /usr/local/bin/enterprise-backup.sh"

# Test run
ssh root@31.56.214.200 "/usr/local/bin/enterprise-backup.sh"
```

### Automated Schedule

```bash
# Add to crontab (daily at 3 AM)
crontab -e

# Add this line:
0 3 * * * /usr/local/bin/enterprise-backup.sh >> /var/log/json2excel-backup.log 2>&1
```

**Current Schedule:**
- **02:00** - Docker cleanup
- **03:00** - Enterprise backup ⭐
- **Every 5 min** - Container recovery

## 📊 Backup Process Flow

### Pre-Flight Phase

1. **Lock Acquisition**
   - Check if backup already running
   - Create lock file with PID
   - Prevent concurrent backups

2. **Directory Setup**
   - Create backup directories if missing
   - Structure: `app/`, `config/`, `redis/`, `uploads/`, `temp/`

3. **Size Estimation**
   ```
   Estimated sizes (uncompressed):
   - App: 372 MB
   - Config: 1 MB
   - Uploads: 1 MB
   - Docker image: 151 MB
   - Redis: 1 MB
   - Total: 526 MB
   - Estimated compressed: 210 MB
   ```

4. **Disk Space Check**
   - Required: 210 MB
   - Safety factor: 1.5x = 315 MB
   - Available: 108 GB ✅
   - Minimum threshold: 5 GB

### Backup Phase

Each component backed up with:
1. **Temp file creation** (`/opt/json2excel/backups/temp/`)
2. **Compression** (gzip level 9)
3. **Verification** (tar -tzf / gzip -t)
4. **Atomic rename** (temp → final)

### Post-Backup Phase

1. **Retention Policy**
   - Daily: Keep 7 days
   - Weekly: Keep 30 days (Sunday backups)
   - Monthly: Keep 90 days (1st of month)

2. **Integrity Verification**
   - Test all tar.gz archives
   - Test all gzip files
   - Report corrupted files

3. **Cleanup**
   - Remove temp files (>60 min old)
   - Apply retention policy

4. **Reporting**
   - Generate summary
   - Log statistics
   - Send alerts

## 📁 Backup Structure

```
/opt/json2excel/backups/
├── app/
│   ├── app-20251210-012857-daily.tar.gz           (1.4M)
│   ├── app-20251210-012857-weekly.tar.gz          (1.4M)
│   ├── app-20251201-030000-monthly.tar.gz         (1.4M)
│   └── docker-image-20251210-012857-daily.tar.gz  (47M)
│
├── config/
│   └── config-20251210-012857-daily.tar.gz        (6K)
│
├── redis/
│   └── redis-20251210-012857-daily.rdb            (88 bytes)
│
├── uploads/
│   └── uploads-20251210-012857-daily.tar.gz       (109 bytes)
│
├── temp/                                           (working directory)
└── incremental/                                    (future use)

Total: ~96 MB
```

## 🔒 Safety Features

### 1. Lock Mechanism
```bash
# Lock file location
/var/run/json2excel-backup.lock

# Contains PID of running backup
# Prevents concurrent runs
# Auto-removes stale locks
```

### 2. Atomic Operations
- All backups created in `temp/` first
- Verified before moving to final location
- No partial backups in production

### 3. Disk Space Guards
```bash
# Minimum free space: 5 GB
# Safety multiplier: 1.5x estimated size
# Pre-flight check blocks backup if insufficient
```

### 4. Verification
- Every archive tested after creation
- Corrupted files detected and reported
- Failed backups don't overwrite good ones

## 📊 Retention Policy

### Daily Backups
- **Retention:** 7 days
- **Tag:** `-daily`
- **Schedule:** Every day at 03:00
- **Purpose:** Quick recovery for recent changes

### Weekly Backups
- **Retention:** 30 days (4 weeks)
- **Tag:** `-weekly`
- **Trigger:** Sunday backups
- **Purpose:** Week-point recovery

### Monthly Backups
- **Retention:** 90 days (3 months)
- **Tag:** `-monthly`
- **Trigger:** 1st of month
- **Purpose:** Long-term compliance

### Storage Optimization

```bash
# Expected storage usage (100 MB per backup):
Daily:   7 days  × 100 MB = 700 MB
Weekly:  4 weeks × 100 MB = 400 MB
Monthly: 3 months× 100 MB = 300 MB
------------------------------------------
Total estimated:           1.4 GB
```

## 🔔 Alert Configuration

### Webhook Notifications

```bash
# Set webhook URL
export ALERT_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK"

# Or add to /etc/environment
echo 'ALERT_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK"' >> /etc/environment
```

### Email Notifications

```bash
# Set email address
export ALERT_EMAIL="admin@yourdomain.com"

# Requires mail command (postfix or sendmail)
dnf install postfix -y
systemctl enable --now postfix
```

### Alert Types

| Event | Severity | Trigger |
|-------|----------|---------|
| Backup successful | info | Every successful backup |
| Partial success | warning | Some components failed |
| Disk space low | warning | < 5 GB free |
| Backup failed | critical | Pre-flight check failed |
| Corrupted files | critical | Verification failed |

## 📝 Logs

### Main Log File
```bash
# Location
/var/log/json2excel-backup.log

# View live
tail -f /var/log/json2excel-backup.log

# View last backup
tail -100 /var/log/json2excel-backup.log

# Search errors
grep -i error /var/log/json2excel-backup.log
```

### Log Format
```
[2025-12-10 01:29:21] [INFO] Starting Enterprise Backup Process
[2025-12-10 01:29:21] [INFO] Lock acquired (PID: 700421)
[2025-12-10 01:29:21] [INFO] Disk space check passed (108 GB available)
[2025-12-10 01:29:21] [SUCCESS] App backup completed: 1.4M
[2025-12-10 01:29:21] [SUCCESS] Docker image backup completed: 47M
[2025-12-10 01:29:21] [SUCCESS] All backups verified successfully
```

## 🛠️ Manual Operations

### Run Backup Manually
```bash
/usr/local/bin/enterprise-backup.sh
```

### Check Backup Status
```bash
# List all backups
ls -lh /opt/json2excel/backups/{app,config,redis,uploads}/

# Check sizes
du -sh /opt/json2excel/backups/*

# Count backups
find /opt/json2excel/backups -name "*.tar.gz" | wc -l
```

### Verify Specific Backup
```bash
# Test tar.gz
tar -tzf /opt/json2excel/backups/app/app-20251210-012857-daily.tar.gz

# Test gzip
gzip -t /opt/json2excel/backups/app/docker-image-20251210-012857-daily.tar.gz
```

### Force Cleanup
```bash
# Remove old backups manually
find /opt/json2excel/backups -type f -mtime +7 -delete

# Remove temp files
rm -rf /opt/json2excel/backups/temp/*
```

## 🔄 Restore Procedures

### 1. Restore Application
```bash
# Extract to temp location
tar -xzf /opt/json2excel/backups/app/app-YYYYMMDD-daily.tar.gz -C /tmp/

# Stop containers
cd /opt/json2excel && docker compose down

# Replace app
rm -rf /opt/json2excel/app
mv /tmp/app /opt/json2excel/

# Rebuild and start
docker compose up -d --build
```

### 2. Restore Docker Image
```bash
# Load image
gunzip -c /opt/json2excel/backups/app/docker-image-YYYYMMDD-daily.tar.gz | docker load

# Verify
docker images | grep json2excel

# Restart containers
docker compose restart
```

### 3. Restore Redis Data
```bash
# Stop Redis container
docker stop json2excel-redis

# Copy RDB file
docker cp /opt/json2excel/backups/redis/redis-YYYYMMDD-daily.rdb json2excel-redis:/data/dump.rdb

# Start Redis
docker start json2excel-redis
```

### 4. Restore Configuration
```bash
# Extract
tar -xzf /opt/json2excel/backups/config/config-YYYYMMDD-daily.tar.gz -C /opt/json2excel/

# Reload
docker compose up -d
```

## 📈 Monitoring

### Daily Checks
```bash
# Check last backup
tail -50 /var/log/json2excel-backup.log

# Verify backup exists
ls -lh /opt/json2excel/backups/app/ | head -5

# Check disk space
df -h /opt/json2excel/backups
```

### Weekly Review
```bash
# Count backups per category
echo "Daily: $(find /opt/json2excel/backups -name "*daily*" | wc -l)"
echo "Weekly: $(find /opt/json2excel/backups -name "*weekly*" | wc -l)"
echo "Monthly: $(find /opt/json2excel/backups -name "*monthly*" | wc -l)"

# Check total size
du -sh /opt/json2excel/backups

# Verify integrity
/usr/local/bin/enterprise-backup.sh --verify-only
```

## 🚨 Troubleshooting

### Backup Not Running
```bash
# Check cron
crontab -l | grep backup

# Check lock file
ls -l /var/run/json2excel-backup.lock

# Remove stale lock
rm -f /var/run/json2excel-backup.lock

# Test manually
/usr/local/bin/enterprise-backup.sh
```

### Disk Space Issues
```bash
# Check available space
df -h /

# Check backup size
du -sh /opt/json2excel/backups

# Force cleanup old backups
find /opt/json2excel/backups -type f -mtime +7 -delete

# Check Docker disk usage
docker system df
```

### Backup Verification Failed
```bash
# Find corrupted files
for f in /opt/json2excel/backups/*/*.tar.gz; do
    tar -tzf "$f" > /dev/null 2>&1 || echo "Corrupted: $f"
done

# Remove corrupted file
rm -f /opt/json2excel/backups/app/corrupted-file.tar.gz

# Run new backup
/usr/local/bin/enterprise-backup.sh
```

### Missing Backups
```bash
# Check cron logs
grep backup /var/log/cron

# Check backup log
tail -100 /var/log/json2excel-backup.log

# Check permissions
ls -ld /opt/json2excel/backups
ls -l /usr/local/bin/enterprise-backup.sh
```

## 🎓 Best Practices

### Do's ✅

1. **Monitor disk space** - Keep at least 10 GB free
2. **Test restores** - Verify backups monthly
3. **Check logs** - Review after each backup
4. **Configure alerts** - Set up webhook/email
5. **Off-site backups** - Copy to remote location weekly
6. **Document process** - Keep restore procedures updated
7. **Version control** - Track changes to backup script

### Don'ts ❌

1. **Don't disable** - Always keep automated backups
2. **Don't delete manually** - Unless disk emergency
3. **Don't skip verification** - Corrupted backups are useless
4. **Don't ignore warnings** - Address disk space issues
5. **Don't run concurrent** - Lock file prevents this
6. **Don't modify temp** - Atomic operations need clean temp
7. **Don't store only local** - Always have off-site copy

## 📦 Off-Site Backup Strategy

### Rsync to Remote Server
```bash
# Daily sync to remote
rsync -avz --delete \
    /opt/json2excel/backups/ \
    remote-server:/backups/json2excel/

# Add to cron (after backup completes)
0 4 * * * rsync -avz /opt/json2excel/backups/ remote:/backups/json2excel/ >> /var/log/rsync-backup.log 2>&1
```

### Cloud Storage (S3/B2)
```bash
# Install rclone
curl https://rclone.org/install.sh | bash

# Configure (interactive)
rclone config

# Sync to cloud
rclone sync /opt/json2excel/backups/ remote:bucket/json2excel-backups/

# Add to cron
0 4 * * * rclone sync /opt/json2excel/backups/ remote:bucket/json2excel-backups/ >> /var/log/cloud-backup.log 2>&1
```

## 📊 Current Status

**Installed:** ✅ `/usr/local/bin/enterprise-backup.sh`  
**Schedule:** ✅ Daily at 03:00 AM  
**Log:** ✅ `/var/log/json2excel-backup.log`  
**Size:** 96 MB (current backups)  
**Free Space:** 108 GB  
**Last Backup:** 2025-12-10 01:29:21  
**Status:** ✅ Operational

---

**Version:** 1.0.0  
**Last Updated:** December 10, 2025  
**Status:** Production Ready ✅
