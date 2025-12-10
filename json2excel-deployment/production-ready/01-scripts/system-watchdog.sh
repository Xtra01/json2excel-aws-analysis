#!/bin/bash

###############################################################################
# System Watchdog - Server Çökme ve Reboot Koruması
# Server reboot olduğunda containerları otomatik başlatır
# Systemd service olarak çalışır
# Log: /var/log/system-watchdog.log
###############################################################################

set -euo pipefail

LOG_FILE="/var/log/system-watchdog.log"
COMPOSE_FILE="/opt/json2excel/docker-compose.yml"
LOCK_FILE="/var/run/system-watchdog.lock"
MAX_WAIT_TIME=300  # 5 minutes

log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $@" | tee -a "$LOG_FILE"
}

###############################################################################
# Lock Management
###############################################################################

acquire_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local pid=$(cat "$LOCK_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            log "Another instance is running (PID: $pid), exiting"
            exit 0
        else
            log "Removing stale lock file"
            rm -f "$LOCK_FILE"
        fi
    fi
    
    echo $$ > "$LOCK_FILE"
}

release_lock() {
    rm -f "$LOCK_FILE"
}

trap release_lock EXIT INT TERM

###############################################################################
# Wait for System to be Ready
###############################################################################

wait_for_system() {
    log "Waiting for system to be fully ready..."
    
    local elapsed=0
    while [ $elapsed -lt $MAX_WAIT_TIME ]; do
        # Check if Docker daemon is running
        if docker info > /dev/null 2>&1; then
            log "Docker daemon is ready"
            return 0
        fi
        
        sleep 5
        elapsed=$((elapsed + 5))
    done
    
    log "ERROR: System not ready after ${MAX_WAIT_TIME}s"
    return 1
}

###############################################################################
# Check if System was Rebooted
###############################################################################

check_reboot() {
    local uptime_seconds=$(awk '{print int($1)}' /proc/uptime)
    local uptime_minutes=$((uptime_seconds / 60))
    
    log "System uptime: ${uptime_minutes} minutes"
    
    # If uptime is less than 10 minutes, likely a reboot
    if [ $uptime_minutes -lt 10 ]; then
        log "Recent reboot detected (uptime: ${uptime_minutes}m)"
        return 0
    fi
    
    return 1
}

###############################################################################
# Start Application Containers
###############################################################################

start_containers() {
    log "========================================="
    log "Starting application containers"
    log "========================================="
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        log "ERROR: Docker compose file not found: $COMPOSE_FILE"
        return 1
    fi
    
    cd "$(dirname $COMPOSE_FILE)"
    
    # Check if containers are already running
    if docker compose ps | grep -q "Up"; then
        log "Containers are already running"
        return 0
    fi
    
    # Start containers
    log "Executing: docker compose up -d"
    if docker compose up -d >> "$LOG_FILE" 2>&1; then
        log "SUCCESS: Containers started successfully"
        sleep 10
        
        # Verify containers are running
        docker compose ps >> "$LOG_FILE" 2>&1
        
        # Test web service
        if curl -sf http://localhost > /dev/null 2>&1; then
            log "SUCCESS: Web service is responding"
        else
            log "WARNING: Web service not responding yet (may need more time)"
        fi
        
        return 0
    else
        log "ERROR: Failed to start containers"
        return 1
    fi
}

###############################################################################
# Health Check and Recovery
###############################################################################

verify_and_recover() {
    log "Performing health check..."
    
    local healthy=true
    local containers=("json2excel-app" "json2excel-nginx" "json2excel-redis")
    
    for container in "${containers[@]}"; do
        if ! docker ps | grep -q "$container"; then
            log "WARNING: Container $container is not running"
            healthy=false
        fi
    done
    
    if ! $healthy; then
        log "Some containers are down, triggering recovery"
        if [ -x /usr/local/bin/container-recovery.sh ]; then
            /usr/local/bin/container-recovery.sh oneshot >> "$LOG_FILE" 2>&1
        else
            log "Recovery script not found, restarting compose"
            docker compose -f "$COMPOSE_FILE" restart >> "$LOG_FILE" 2>&1
        fi
    fi
}

###############################################################################
# Send Boot Notification
###############################################################################

send_boot_notification() {
    local uptime=$(uptime -p 2>/dev/null || uptime)
    local ip=$(hostname -I | awk '{print $1}')
    
    log "========================================="
    log "System Boot Notification"
    log "Hostname: $(hostname)"
    log "IP Address: $ip"
    log "Uptime: $uptime"
    log "Docker containers: $(docker ps --format '{{.Names}}' | wc -l) running"
    log "========================================="
}

###############################################################################
# Main
###############################################################################

main() {
    log "========================================="
    log "System Watchdog Started"
    log "========================================="
    
    # Acquire lock
    acquire_lock
    
    # Wait for system to be ready
    if ! wait_for_system; then
        log "CRITICAL: System initialization failed"
        exit 1
    fi
    
    # Check if this is a reboot
    if check_reboot; then
        log "Post-reboot startup detected"
        
        # Start containers
        if start_containers; then
            log "Post-reboot container startup successful"
            
            # Additional verification after 30 seconds
            sleep 30
            verify_and_recover
            
            # Send notification
            send_boot_notification
        else
            log "CRITICAL: Failed to start containers after reboot"
            exit 1
        fi
    else
        log "Normal system check (not a recent reboot)"
        
        # Just verify containers are running
        verify_and_recover
    fi
    
    log "System Watchdog completed successfully"
    log "========================================="
}

# Execute
main "$@"
