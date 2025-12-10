#!/bin/bash

###############################################################################
# Docker Cleanup Script - Günlük Temizlik ve Optimizasyon
# Kullanılmayan Docker image, container, volume, network temizliği
# Log: /var/log/docker-cleanup.log
###############################################################################

set -euo pipefail

# Configuration
LOG_FILE="/var/log/docker-cleanup.log"
MAX_LOG_SIZE=10485760  # 10MB
RETENTION_DAYS=7
ALERT_THRESHOLD_GB=10

# Colors for console output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

log_warn() {
    log "WARN" "$@"
    echo -e "${YELLOW}[WARN] $@${NC}"
}

log_error() {
    log "ERROR" "$@"
    echo -e "${RED}[ERROR] $@${NC}"
}

log_success() {
    log "SUCCESS" "$@"
    echo -e "${GREEN}[SUCCESS] $@${NC}"
}

###############################################################################
# Log Rotation
###############################################################################

rotate_log() {
    if [ -f "$LOG_FILE" ]; then
        local log_size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
        if [ "$log_size" -gt "$MAX_LOG_SIZE" ]; then
            log_info "Rotating log file (size: $(numfmt --to=iec $log_size))"
            mv "$LOG_FILE" "${LOG_FILE}.1"
            gzip -f "${LOG_FILE}.1"
            
            # Keep only last 5 rotated logs
            find "$(dirname $LOG_FILE)" -name "$(basename $LOG_FILE).*.gz" -mtime +30 -delete
        fi
    fi
}

###############################################################################
# Disk Space Check
###############################################################################

check_disk_space() {
    local available_gb=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    log_info "Available disk space: ${available_gb}GB"
    
    if [ "$available_gb" -lt "$ALERT_THRESHOLD_GB" ]; then
        log_warn "Low disk space detected: ${available_gb}GB remaining"
        return 1
    fi
    return 0
}

###############################################################################
# Docker Cleanup Functions
###############################################################################

cleanup_stopped_containers() {
    log_info "Cleaning up stopped containers..."
    local count=$(docker ps -a -q -f status=exited -f status=created | wc -l)
    
    if [ "$count" -gt 0 ]; then
        docker container prune -f >> "$LOG_FILE" 2>&1
        log_success "Removed $count stopped containers"
    else
        log_info "No stopped containers to remove"
    fi
}

cleanup_dangling_images() {
    log_info "Cleaning up dangling images..."
    local count=$(docker images -f "dangling=true" -q | wc -l)
    
    if [ "$count" -gt 0 ]; then
        docker image prune -f >> "$LOG_FILE" 2>&1
        log_success "Removed $count dangling images"
    else
        log_info "No dangling images to remove"
    fi
}

cleanup_old_images() {
    log_info "Cleaning up unused images older than ${RETENTION_DAYS} days..."
    local before_count=$(docker images -a | wc -l)
    
    # Podman uses different time format: 168h = 7 days
    local hours=$((RETENTION_DAYS * 24))
    docker image prune -a -f --filter "until=${hours}h" >> "$LOG_FILE" 2>&1
    
    local after_count=$(docker images -a | wc -l)
    local removed=$((before_count - after_count))
    
    if [ "$removed" -gt 0 ]; then
        log_success "Removed $removed old images"
    else
        log_info "No old images to remove"
    fi
}

cleanup_unused_volumes() {
    log_info "Cleaning up unused volumes..."
    local count=$(docker volume ls -qf dangling=true | wc -l)
    
    if [ "$count" -gt 0 ]; then
        docker volume prune -f >> "$LOG_FILE" 2>&1
        log_success "Removed $count unused volumes"
    else
        log_info "No unused volumes to remove"
    fi
}

cleanup_unused_networks() {
    log_info "Cleaning up unused networks..."
    local before_count=$(docker network ls | wc -l)
    
    docker network prune -f >> "$LOG_FILE" 2>&1
    
    local after_count=$(docker network ls | wc -l)
    local removed=$((before_count - after_count))
    
    if [ "$removed" -gt 0 ]; then
        log_success "Removed $removed unused networks"
    else
        log_info "No unused networks to remove"
    fi
}

cleanup_build_cache() {
    log_info "Cleaning up build cache..."
    local cache_size_before=$(docker system df | awk '/Build Cache/ {print $4}')
    
    # Podman uses different time format: 168h = 7 days
    local hours=$((RETENTION_DAYS * 24))
    docker builder prune -f --filter "until=${hours}h" >> "$LOG_FILE" 2>&1 || log_info "Build cache cleanup not available"
    
    local cache_size_after=$(docker system df | awk '/Build Cache/ {print $4}')
    log_success "Build cache: $cache_size_before → $cache_size_after"
}

###############################################################################
# System Logs Cleanup
###############################################################################

cleanup_system_logs() {
    log_info "Cleaning up old system logs..."
    
    # Clean journald logs older than 7 days
    journalctl --vacuum-time=7d >> "$LOG_FILE" 2>&1
    
    # Clean old container logs
    find /var/lib/docker/containers/ -name "*-json.log" -mtime +7 -delete 2>/dev/null || true
    
    log_success "System logs cleaned"
}

###############################################################################
# Container Logs Rotation
###############################################################################

rotate_container_logs() {
    log_info "Rotating container logs..."
    
    for container in $(docker ps -q); do
        local container_name=$(docker inspect --format='{{.Name}}' $container | sed 's/^\///')
        local log_path=$(docker inspect --format='{{.LogPath}}' $container)
        
        if [ -f "$log_path" ]; then
            local log_size=$(stat -c%s "$log_path" 2>/dev/null || echo 0)
            if [ "$log_size" -gt 104857600 ]; then  # 100MB
                log_info "Rotating logs for $container_name ($(numfmt --to=iec $log_size))"
                docker logs --tail 1000 "$container" > "/tmp/${container_name}.log" 2>&1
                : > "$log_path"  # Truncate log file
            fi
        fi
    done
    
    log_success "Container logs rotated"
}

###############################################################################
# Statistics Report
###############################################################################

generate_report() {
    log_info "========================================="
    log_info "Docker Cleanup Report"
    log_info "========================================="
    
    # System info
    log_info "System: $(uname -n)"
    log_info "Date: $(date '+%Y-%m-%d %H:%M:%S')"
    
    # Disk usage
    log_info "-----------------------------------------"
    log_info "Disk Usage:"
    df -h / | tail -1 | awk '{print "  Total: "$2", Used: "$3", Available: "$4", Usage: "$5}' | tee -a "$LOG_FILE"
    
    # Docker stats
    log_info "-----------------------------------------"
    log_info "Docker Resources:"
    docker system df >> "$LOG_FILE" 2>&1
    
    # Container status
    log_info "-----------------------------------------"
    log_info "Running Containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Size}}" >> "$LOG_FILE" 2>&1
    
    log_info "========================================="
}

###############################################################################
# Main Execution
###############################################################################

main() {
    log_info "========================================="
    log_info "Starting Docker Cleanup"
    log_info "========================================="
    
    # Rotate log if needed
    rotate_log
    
    # Check disk space
    if ! check_disk_space; then
        log_warn "Forcing aggressive cleanup due to low disk space"
    fi
    
    # Docker cleanup
    cleanup_stopped_containers
    cleanup_dangling_images
    cleanup_old_images
    cleanup_unused_volumes
    cleanup_unused_networks
    cleanup_build_cache
    
    # System cleanup
    cleanup_system_logs
    rotate_container_logs
    
    # Generate report
    generate_report
    
    log_success "Docker cleanup completed successfully"
    log_info "========================================="
}

# Execute main function
main "$@"
