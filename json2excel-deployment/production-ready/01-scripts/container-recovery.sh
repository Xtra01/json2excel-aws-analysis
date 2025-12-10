#!/bin/bash

###############################################################################
# Container Auto-Recovery Script
# Containerları otomatik yeniden başlatır ve health check yapar
# Log: /var/log/container-recovery.log
###############################################################################

set -euo pipefail

# Configuration
LOG_FILE="/var/log/container-recovery.log"
COMPOSE_FILE="/opt/json2excel/docker-compose.yml"
MAX_RESTART_ATTEMPTS=3
HEALTH_CHECK_RETRIES=5
HEALTH_CHECK_INTERVAL=10
ALERT_WEBHOOK="${ALERT_WEBHOOK:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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
# Alert Functions
###############################################################################

send_alert() {
    local title="$1"
    local message="$2"
    local severity="${3:-warning}"
    
    log_info "Alert: $title - $message"
    
    if [ -n "$ALERT_WEBHOOK" ]; then
        curl -X POST "$ALERT_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "{\"title\":\"$title\",\"message\":\"$message\",\"severity\":\"$severity\",\"host\":\"$(hostname)\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
            >> "$LOG_FILE" 2>&1 || log_warn "Failed to send webhook alert"
    fi
}

###############################################################################
# Container Health Check
###############################################################################

check_container_health() {
    local container_name=$1
    local container_id=$(docker ps -q -f name="$container_name")
    
    if [ -z "$container_id" ]; then
        log_error "Container $container_name is not running"
        return 1
    fi
    
    local health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_id" 2>/dev/null || echo "none")
    
    if [ "$health_status" = "healthy" ]; then
        log_success "Container $container_name is healthy"
        return 0
    elif [ "$health_status" = "none" ]; then
        # No health check defined, check if running
        local running=$(docker inspect --format='{{.State.Running}}' "$container_id")
        if [ "$running" = "true" ]; then
            log_info "Container $container_name is running (no healthcheck defined)"
            return 0
        fi
    fi
    
    log_warn "Container $container_name health: $health_status"
    return 1
}

###############################################################################
# Web Health Check
###############################################################################

check_web_health() {
    local url="http://localhost"
    local retry=0
    
    log_info "Checking web service at $url"
    
    while [ $retry -lt $HEALTH_CHECK_RETRIES ]; do
        if curl -sf -o /dev/null -w "%{http_code}" "$url" | grep -q "^[23]"; then
            log_success "Web service is responding"
            return 0
        fi
        
        retry=$((retry + 1))
        log_warn "Web check failed (attempt $retry/$HEALTH_CHECK_RETRIES)"
        sleep $HEALTH_CHECK_INTERVAL
    done
    
    log_error "Web service is not responding after $HEALTH_CHECK_RETRIES attempts"
    return 1
}

###############################################################################
# Container Restart Functions
###############################################################################

restart_container() {
    local container_name=$1
    local attempt=${2:-1}
    
    log_info "Restarting container: $container_name (attempt $attempt/$MAX_RESTART_ATTEMPTS)"
    
    if docker restart "$container_name" >> "$LOG_FILE" 2>&1; then
        log_success "Container $container_name restarted successfully"
        sleep 5
        return 0
    else
        log_error "Failed to restart container $container_name"
        return 1
    fi
}

restart_all_containers() {
    log_info "Restarting all containers using docker-compose"
    
    cd "$(dirname $COMPOSE_FILE)"
    
    if docker compose restart >> "$LOG_FILE" 2>&1; then
        log_success "All containers restarted successfully"
        sleep 10
        return 0
    else
        log_error "Failed to restart containers"
        return 1
    fi
}

rebuild_and_restart() {
    log_warn "Attempting full rebuild and restart"
    send_alert "Container Recovery" "Performing full rebuild due to persistent failures" "critical"
    
    cd "$(dirname $COMPOSE_FILE)"
    
    # Stop all containers
    docker compose down >> "$LOG_FILE" 2>&1
    
    # Start containers
    docker compose up -d >> "$LOG_FILE" 2>&1
    
    sleep 15
    
    if check_web_health; then
        log_success "Rebuild and restart successful"
        send_alert "Container Recovery" "System recovered after rebuild" "info"
        return 0
    else
        log_error "Rebuild failed to restore service"
        send_alert "Container Recovery" "CRITICAL: Rebuild failed, manual intervention required" "critical"
        return 1
    fi
}

###############################################################################
# Container Recovery Logic
###############################################################################

recover_container() {
    local container_name=$1
    local attempt=1
    
    log_info "========================================="
    log_info "Recovery initiated for: $container_name"
    log_info "========================================="
    
    while [ $attempt -le $MAX_RESTART_ATTEMPTS ]; do
        log_info "Recovery attempt $attempt/$MAX_RESTART_ATTEMPTS"
        
        if restart_container "$container_name" "$attempt"; then
            sleep 5
            if check_container_health "$container_name"; then
                log_success "Container $container_name recovered successfully"
                return 0
            fi
        fi
        
        attempt=$((attempt + 1))
        if [ $attempt -le $MAX_RESTART_ATTEMPTS ]; then
            log_info "Waiting before next attempt..."
            sleep 10
        fi
    done
    
    log_error "Failed to recover $container_name after $MAX_RESTART_ATTEMPTS attempts"
    send_alert "Container Failure" "Container $container_name failed to recover" "critical"
    return 1
}

###############################################################################
# System Recovery
###############################################################################

full_system_recovery() {
    log_warn "========================================="
    log_warn "Initiating Full System Recovery"
    log_warn "========================================="
    
    send_alert "System Recovery" "Full system recovery initiated" "warning"
    
    # Try compose restart first
    if restart_all_containers; then
        sleep 10
        if check_web_health; then
            log_success "System recovered with compose restart"
            send_alert "System Recovery" "System recovered successfully" "info"
            return 0
        fi
    fi
    
    # If that fails, try full rebuild
    rebuild_and_restart
}

###############################################################################
# Main Monitoring Loop
###############################################################################

monitor_containers() {
    log_info "========================================="
    log_info "Starting Container Health Monitoring"
    log_info "========================================="
    
    local containers=("json2excel-app" "json2excel-nginx" "json2excel-redis")
    local failed_containers=()
    
    # Check each container
    for container in "${containers[@]}"; do
        if ! check_container_health "$container"; then
            failed_containers+=("$container")
        fi
    done
    
    # Handle failures
    if [ ${#failed_containers[@]} -eq 0 ]; then
        log_success "All containers are healthy"
        
        # Additional web check
        if ! check_web_health; then
            log_warn "Web check failed despite healthy containers"
            full_system_recovery
        fi
    elif [ ${#failed_containers[@]} -eq 1 ]; then
        # Single container failure - try individual recovery
        log_warn "Single container failure detected"
        if ! recover_container "${failed_containers[0]}"; then
            log_warn "Individual recovery failed, attempting full system recovery"
            full_system_recovery
        fi
    else
        # Multiple container failures - go straight to full recovery
        log_error "Multiple container failures detected: ${failed_containers[*]}"
        full_system_recovery
    fi
    
    log_info "========================================="
}

###############################################################################
# One-time Recovery Mode
###############################################################################

oneshot_recovery() {
    monitor_containers
}

###############################################################################
# Daemon Mode (continuous monitoring)
###############################################################################

daemon_mode() {
    log_info "Starting in daemon mode (monitoring every 5 minutes)"
    
    while true; do
        monitor_containers
        sleep 300  # 5 minutes
    done
}

###############################################################################
# Main
###############################################################################

main() {
    local mode="${1:-oneshot}"
    
    case "$mode" in
        daemon)
            daemon_mode
            ;;
        oneshot|*)
            oneshot_recovery
            ;;
    esac
}

# Execute
main "$@"
