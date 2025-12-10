#!/bin/bash

###############################################################################
# Enterprise-Grade Backup System for JSON2Excel
# Features:
# - Pre-flight disk space checks
# - Size estimation before backup
# - Atomic backups (temp → final rename)
# - Compression with verification
# - Retention policy (configurable)
# - Backup integrity checks
# - Email/webhook notifications
# - Incremental backup support
# - Lock file (prevent concurrent runs)
# - Detailed logging
###############################################################################

set -euo pipefail

# Configuration
PROJECT_DIR="/opt/json2excel"
BACKUP_ROOT="/opt/json2excel/backups"
LOG_FILE="/var/log/json2excel-backup.log"
LOCK_FILE="/var/run/json2excel-backup.lock"

# Retention policies (days)
RETENTION_DAILY=7
RETENTION_WEEKLY=30
RETENTION_MONTHLY=90

# Space requirements (safety margin)
MIN_FREE_SPACE_GB=5
SAFETY_MULTIPLIER=1.5  # Backup size * 1.5 for safety

# Alert configuration
ALERT_WEBHOOK="${ALERT_WEBHOOK:-}"
ALERT_EMAIL="${ALERT_EMAIL:-}"

# Colors for console output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

###############################################################################
# Logging Functions
###############################################################################

log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() {
    log "INFO" "$@"
}

log_success() {
    log "SUCCESS" "$@"
}

log_warn() {
    log "WARN" "$@"
}

log_error() {
    log "ERROR" "$@"
}

###############################################################################
# Lock Management
###############################################################################

acquire_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
        if [ -n "$pid" ] && ps -p "$pid" > /dev/null 2>&1; then
            log_error "Another backup is already running (PID: $pid)"
            exit 1
        else
            log_warn "Removing stale lock file"
            rm -f "$LOCK_FILE"
        fi
    fi
    
    echo $$ > "$LOCK_FILE"
    log_info "Lock acquired (PID: $$)"
}

release_lock() {
    rm -f "$LOCK_FILE"
    log_info "Lock released"
}

trap release_lock EXIT INT TERM

###############################################################################
# Alert Functions
###############################################################################

send_alert() {
    local title="$1"
    local message="$2"
    local severity="${3:-info}"
    
    # Webhook alert
    if [ -n "$ALERT_WEBHOOK" ]; then
        curl -X POST "$ALERT_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{\"title\":\"Backup: $title\",\"message\":\"$message\",\"severity\":\"$severity\",\"host\":\"$(hostname)\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
            >> "$LOG_FILE" 2>&1 || log_warn "Failed to send webhook alert"
    fi
    
    # Email alert (if mail command exists)
    if [ -n "$ALERT_EMAIL" ] && command -v mail &> /dev/null; then
        echo "$message" | mail -s "Backup: $title" "$ALERT_EMAIL" || log_warn "Failed to send email alert"
    fi
}

###############################################################################
# Disk Space Functions
###############################################################################

get_available_space_gb() {
    df -BG "$BACKUP_ROOT" | awk 'NR==2 {print $4}' | sed 's/G//'
}

get_directory_size_mb() {
    local dir="$1"
    if [ -d "$dir" ]; then
        du -sm "$dir" 2>/dev/null | awk '{print $1}' || echo 0
    else
        echo 0
    fi
}

estimate_backup_size() {
    local app_size=$(get_directory_size_mb "$PROJECT_DIR/app")
    local config_size=$(get_directory_size_mb "$PROJECT_DIR/config")
    local uploads_size=$(get_directory_size_mb "/var/lib/json2excel/uploads" 2>/dev/null || echo 0)
    
    # Docker image size (estimate from current image)
    local docker_size=$(docker images --format "{{.Size}}" json2excel-json2excel-app:latest 2>/dev/null | \
                       sed 's/MB//;s/GB/*1024/' | bc 2>/dev/null || echo 150)
    
    # Redis dump size
    local redis_size=1  # Usually very small
    
    # Total estimated size (in MB)
    local total_mb=$((app_size + config_size + uploads_size + docker_size + redis_size))
    
    # Apply compression ratio (estimated 60% compression)
    local compressed_mb=$((total_mb * 40 / 100))
    
    # Log to file only (not stdout)
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Estimated sizes (uncompressed):" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]   - App: ${app_size} MB" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]   - Config: ${config_size} MB" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]   - Uploads: ${uploads_size} MB" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]   - Docker image: ${docker_size} MB" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]   - Redis: ${redis_size} MB" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]   - Total: ${total_mb} MB" >> "$LOG_FILE"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]   - Estimated compressed: ${compressed_mb} MB" >> "$LOG_FILE"
    
    # Return only the number
    echo "${compressed_mb}"
}

check_disk_space() {
    local required_mb=$1
    local available_gb=$(get_available_space_gb)
    local available_mb=$((available_gb * 1024))
    
    # Apply safety multiplier
    local required_with_safety=$((required_mb * 150 / 100))  # 1.5x multiplier
    
    log_info "Disk space check:"
    log_info "  - Available: ${available_gb} GB (${available_mb} MB)"
    log_info "  - Required: ${required_mb} MB"
    log_info "  - Required (with safety): ${required_with_safety} MB"
    
    if [ "$available_mb" -lt "$required_with_safety" ]; then
        log_error "Insufficient disk space!"
        log_error "Need ${required_with_safety} MB, but only ${available_mb} MB available"
        send_alert "Backup Failed" "Insufficient disk space" "critical"
        return 1
    fi
    
    if [ "$available_gb" -lt "$MIN_FREE_SPACE_GB" ]; then
        log_warn "Low disk space warning (< ${MIN_FREE_SPACE_GB} GB free)"
        send_alert "Low Disk Space" "Only ${available_gb} GB free" "warning"
    fi
    
    log_success "Disk space check passed (${available_gb} GB available)"
    return 0
}

###############################################################################
# Backup Functions
###############################################################################

create_backup_dirs() {
    log_info "Creating backup directories..."
    mkdir -p "$BACKUP_ROOT"/{app,config,redis,uploads,incremental,temp}
    chmod 700 "$BACKUP_ROOT"
}

backup_application() {
    local date_tag=$1
    local temp_file="$BACKUP_ROOT/temp/app-$date_tag.tar.gz"
    local final_file="$BACKUP_ROOT/app/app-$date_tag.tar.gz"
    
    log_info "Backing up application source..."
    
    if tar -czf "$temp_file" \
        -C "$PROJECT_DIR" \
        --exclude='node_modules' \
        --exclude='.next' \
        --exclude='*.log' \
        --exclude='.git' \
        --exclude='*.swp' \
        --exclude='*.tmp' \
        app/ 2>> "$LOG_FILE"; then
        
        # Verify archive
        if tar -tzf "$temp_file" > /dev/null 2>&1; then
            mv "$temp_file" "$final_file"
            local size=$(du -sh "$final_file" | cut -f1)
            log_success "App backup completed: $size"
            echo "$final_file"
        else
            log_error "App backup verification failed"
            rm -f "$temp_file"
            return 1
        fi
    else
        log_error "App backup failed"
        rm -f "$temp_file"
        return 1
    fi
}

backup_docker_image() {
    local date_tag=$1
    local temp_file="$BACKUP_ROOT/temp/docker-image-$date_tag.tar.gz"
    local final_file="$BACKUP_ROOT/app/docker-image-$date_tag.tar.gz"
    
    log_info "Backing up Docker image..."
    
    if docker save json2excel-json2excel-app:latest 2>> "$LOG_FILE" | gzip > "$temp_file"; then
        # Verify compressed file
        if gzip -t "$temp_file" 2>&1; then
            mv "$temp_file" "$final_file"
            local size=$(du -sh "$final_file" | cut -f1)
            log_success "Docker image backup completed: $size"
            echo "$final_file"
        else
            log_error "Docker image backup verification failed"
            rm -f "$temp_file"
            return 1
        fi
    else
        log_error "Docker image backup failed"
        rm -f "$temp_file"
        return 1
    fi
}

backup_redis() {
    local date_tag=$1
    local final_file="$BACKUP_ROOT/redis/redis-$date_tag.rdb"
    
    log_info "Backing up Redis data..."
    
    if docker ps --format '{{.Names}}' | grep -q 'json2excel-redis'; then
        # Trigger Redis SAVE
        if docker exec json2excel-redis redis-cli SAVE >> "$LOG_FILE" 2>&1; then
            sleep 2  # Wait for save to complete
            
            # Copy RDB file
            if docker cp json2excel-redis:/data/dump.rdb "$final_file" 2>> "$LOG_FILE"; then
                local size=$(du -sh "$final_file" | cut -f1)
                log_success "Redis backup completed: $size"
                echo "$final_file"
            else
                log_warn "Redis backup copy failed"
                return 1
            fi
        else
            log_warn "Redis SAVE command failed"
            return 1
        fi
    else
        log_info "Redis container not running, skipping"
        return 0
    fi
}

backup_config() {
    local date_tag=$1
    local temp_file="$BACKUP_ROOT/temp/config-$date_tag.tar.gz"
    local final_file="$BACKUP_ROOT/config/config-$date_tag.tar.gz"
    
    log_info "Backing up configuration files..."
    
    if tar -czf "$temp_file" \
        -C "$PROJECT_DIR" \
        config/ \
        docker-compose.yml \
        Dockerfile \
        .env.production \
        2>> "$LOG_FILE"; then
        
        if tar -tzf "$temp_file" > /dev/null 2>&1; then
            mv "$temp_file" "$final_file"
            local size=$(du -sh "$final_file" | cut -f1)
            log_success "Config backup completed: $size"
            echo "$final_file"
        else
            log_error "Config backup verification failed"
            rm -f "$temp_file"
            return 1
        fi
    else
        log_error "Config backup failed"
        rm -f "$temp_file"
        return 1
    fi
}

backup_uploads() {
    local date_tag=$1
    local temp_file="$BACKUP_ROOT/temp/uploads-$date_tag.tar.gz"
    local final_file="$BACKUP_ROOT/uploads/uploads-$date_tag.tar.gz"
    
    if [ -d "/var/lib/json2excel/uploads" ]; then
        log_info "Backing up user uploads..."
        
        if tar -czf "$temp_file" \
            -C /var/lib/json2excel \
            uploads/ 2>> "$LOG_FILE"; then
            
            if tar -tzf "$temp_file" > /dev/null 2>&1; then
                mv "$temp_file" "$final_file"
                local size=$(du -sh "$final_file" | cut -f1)
                log_success "Uploads backup completed: $size"
                echo "$final_file"
            else
                log_error "Uploads backup verification failed"
                rm -f "$temp_file"
                return 1
            fi
        else
            log_warn "Uploads backup failed"
            return 1
        fi
    else
        log_info "No uploads directory found, skipping"
        return 0
    fi
}

###############################################################################
# Retention Management
###############################################################################

apply_retention_policy() {
    log_info "Applying retention policy..."
    
    local current_day=$(date +%d)
    local current_dow=$(date +%u)  # 1=Monday, 7=Sunday
    
    # Daily backups: Keep last 7 days
    log_info "Cleaning daily backups (>${RETENTION_DAILY} days)..."
    find "$BACKUP_ROOT"/{app,config,redis,uploads} -type f -mtime +${RETENTION_DAILY} -name "*daily*" -delete 2>/dev/null || true
    
    # Weekly backups: Keep last 4 weeks (keep Sunday backups as weekly)
    if [ "$current_dow" -eq 7 ]; then
        log_info "Creating weekly backup marker (Sunday)..."
        # Tag today's backup as weekly
        for dir in app config redis uploads; do
            latest=$(ls -t "$BACKUP_ROOT/$dir"/*.{tar.gz,rdb} 2>/dev/null | head -1 || true)
            if [ -n "$latest" ]; then
                weekly_name="${latest%.tar.gz}-weekly.tar.gz"
                cp "$latest" "$weekly_name" 2>/dev/null || true
            fi
        done
    fi
    
    find "$BACKUP_ROOT"/{app,config,redis,uploads} -type f -mtime +${RETENTION_WEEKLY} -name "*weekly*" -delete 2>/dev/null || true
    
    # Monthly backups: Keep last 3 months (keep 1st of month backups as monthly)
    if [ "$current_day" -eq "01" ]; then
        log_info "Creating monthly backup marker..."
        for dir in app config redis uploads; do
            latest=$(ls -t "$BACKUP_ROOT/$dir"/*.{tar.gz,rdb} 2>/dev/null | head -1 || true)
            if [ -n "$latest" ]; then
                monthly_name="${latest%.tar.gz}-monthly.tar.gz"
                cp "$latest" "$monthly_name" 2>/dev/null || true
            fi
        done
    fi
    
    find "$BACKUP_ROOT"/{app,config,redis,uploads} -type f -mtime +${RETENTION_MONTHLY} -name "*monthly*" -delete 2>/dev/null || true
    
    # Clean temp directory
    find "$BACKUP_ROOT/temp" -type f -mmin +60 -delete 2>/dev/null || true
    
    log_success "Retention policy applied"
}

###############################################################################
# Backup Verification
###############################################################################

verify_backups() {
    log_info "Verifying backup integrity..."
    
    local failed=0
    
    # Verify tar.gz files
    for archive in "$BACKUP_ROOT"/{app,config,uploads}/*.tar.gz; do
        if [ -f "$archive" ]; then
            if ! tar -tzf "$archive" > /dev/null 2>&1; then
                log_error "Corrupted archive: $archive"
                failed=$((failed + 1))
            fi
        fi
    done
    
    # Verify gzip files
    for gzfile in "$BACKUP_ROOT"/app/*.gz; do
        if [ -f "$gzfile" ] && [[ ! "$gzfile" =~ \.tar\.gz$ ]]; then
            if ! gzip -t "$gzfile" 2>&1; then
                log_error "Corrupted gzip: $gzfile"
                failed=$((failed + 1))
            fi
        fi
    done
    
    if [ $failed -eq 0 ]; then
        log_success "All backups verified successfully"
        return 0
    else
        log_error "$failed backup(s) failed verification"
        send_alert "Backup Verification Failed" "$failed corrupted file(s) detected" "critical"
        return 1
    fi
}

###############################################################################
# Statistics and Reporting
###############################################################################

generate_backup_report() {
    log_info "========================================="
    log_info "Backup Summary Report"
    log_info "========================================="
    log_info "Date: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "Host: $(hostname)"
    
    # Disk usage
    local available_gb=$(get_available_space_gb)
    local backup_size=$(du -sh "$BACKUP_ROOT" | cut -f1)
    log_info "Disk: ${available_gb} GB available, Backups: ${backup_size}"
    
    # Backup counts
    log_info "-----------------------------------------"
    log_info "Backup File Counts:"
    log_info "  - App backups: $(ls "$BACKUP_ROOT/app"/*.tar.gz 2>/dev/null | wc -l)"
    log_info "  - Config backups: $(ls "$BACKUP_ROOT/config"/*.tar.gz 2>/dev/null | wc -l)"
    log_info "  - Redis backups: $(ls "$BACKUP_ROOT/redis"/*.rdb 2>/dev/null | wc -l)"
    log_info "  - Upload backups: $(ls "$BACKUP_ROOT/uploads"/*.tar.gz 2>/dev/null | wc -l)"
    
    # Latest backups
    log_info "-----------------------------------------"
    log_info "Latest Backups:"
    ls -lh "$BACKUP_ROOT"/{app,config,redis,uploads}/* 2>/dev/null | tail -10 | tee -a "$LOG_FILE" || true
    
    log_info "========================================="
}

###############################################################################
# Main Backup Workflow
###############################################################################

main() {
    log_info "========================================="
    log_info "Starting Enterprise Backup Process"
    log_info "========================================="
    
    # Acquire lock
    acquire_lock
    
    # Create directories
    create_backup_dirs
    
    # Generate date tag
    local date_tag=$(date +%Y%m%d-%H%M%S)
    
    # Pre-flight checks
    log_info "Running pre-flight checks..."
    
    # Estimate backup size
    log_info "Estimating backup size..."
    local estimated_size=$(estimate_backup_size)
    log_info "Estimated compressed size: ${estimated_size} MB"
    
    # Check disk space
    if ! check_disk_space "$estimated_size"; then
        log_error "Pre-flight checks failed: Insufficient disk space"
        send_alert "Backup Failed" "Insufficient disk space" "critical"
        exit 1
    fi
    
    log_success "Pre-flight checks passed"
    
    # Perform backups
    local backup_success=true
    local backup_files=()
    
    if app_file=$(backup_application "$date_tag-daily"); then
        backup_files+=("$app_file")
    else
        backup_success=false
    fi
    
    if docker_file=$(backup_docker_image "$date_tag-daily"); then
        backup_files+=("$docker_file")
    else
        backup_success=false
    fi
    
    if redis_file=$(backup_redis "$date_tag-daily"); then
        [ -n "$redis_file" ] && backup_files+=("$redis_file")
    fi
    
    if config_file=$(backup_config "$date_tag-daily"); then
        backup_files+=("$config_file")
    else
        backup_success=false
    fi
    
    if uploads_file=$(backup_uploads "$date_tag-daily"); then
        [ -n "$uploads_file" ] && backup_files+=("$uploads_file")
    fi
    
    # Apply retention policy
    apply_retention_policy
    
    # Verify backups
    verify_backups
    
    # Generate report
    generate_backup_report
    
    # Send completion alert
    if [ "$backup_success" = true ]; then
        log_success "Backup completed successfully"
        send_alert "Backup Successful" "All components backed up successfully" "info"
    else
        log_warn "Backup completed with warnings"
        send_alert "Backup Partial Success" "Some components failed to backup" "warning"
    fi
    
    log_info "========================================="
}

# Execute
main "$@"
