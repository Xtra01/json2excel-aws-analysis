#!/bin/bash

###############################################################################
# Professional Production Setup Script
# Installs all automation systems:
# - Docker cleanup (daily)
# - Container recovery (monitoring every 5min)
# - System watchdog (post-reboot recovery)
# - Systemd services
# - Centralized logging
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_info() { echo -e "${BLUE}[INFO]${NC} $@"; }
echo_success() { echo -e "${GREEN}[SUCCESS]${NC} $@"; }
echo_warn() { echo -e "${YELLOW}[WARN]${NC} $@"; }
echo_error() { echo -e "${RED}[ERROR]${NC} $@"; }

###############################################################################
# Check Prerequisites
###############################################################################

check_prerequisites() {
    echo_info "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        echo_error "Docker/Podman is not installed"
        exit 1
    fi
    
    # Check if docker command works (could be podman alias)
    if ! docker info &> /dev/null; then
        echo_error "Docker/Podman is not responding"
        exit 1
    fi
    
    echo_success "Prerequisites OK (using $(docker --version))"
}

###############################################################################
# Install Scripts
###############################################################################

install_scripts() {
    echo_info "Installing system scripts..."
    
    # Create log directory
    mkdir -p /var/log
    
    # Install docker cleanup script
    if [ -f "$SCRIPT_DIR/docker-cleanup.sh" ]; then
        install -m 755 "$SCRIPT_DIR/docker-cleanup.sh" /usr/local/bin/
        echo_success "Installed: docker-cleanup.sh"
    fi
    
    # Install container recovery script
    if [ -f "$SCRIPT_DIR/container-recovery.sh" ]; then
        install -m 755 "$SCRIPT_DIR/container-recovery.sh" /usr/local/bin/
        echo_success "Installed: container-recovery.sh"
    fi
    
    # Install system watchdog script
    if [ -f "$SCRIPT_DIR/system-watchdog.sh" ]; then
        install -m 755 "$SCRIPT_DIR/system-watchdog.sh" /usr/local/bin/
        echo_success "Installed: system-watchdog.sh"
    fi
    
    echo_success "All scripts installed"
}

###############################################################################
# Setup Systemd Services
###############################################################################

install_systemd_services() {
    echo_info "Installing systemd services..."
    
    # Install json2excel service
    if [ -f "$SCRIPT_DIR/json2excel.service" ]; then
        install -m 644 "$SCRIPT_DIR/json2excel.service" /etc/systemd/system/
        echo_success "Installed: json2excel.service"
    fi
    
    # Install system watchdog service
    if [ -f "$SCRIPT_DIR/system-watchdog.service" ]; then
        install -m 644 "$SCRIPT_DIR/system-watchdog.service" /etc/systemd/system/
        echo_success "Installed: system-watchdog.service"
    fi
    
    # Reload systemd
    systemctl daemon-reload
    
    # Enable services
    echo_info "Enabling services..."
    systemctl enable json2excel.service
    systemctl enable system-watchdog.service
    
    echo_success "Systemd services installed and enabled"
}

###############################################################################
# Setup Cron Jobs
###############################################################################

setup_cron_jobs() {
    echo_info "Setting up cron jobs..."
    
    # Remove old cron jobs
    crontab -l 2>/dev/null | grep -v "docker-cleanup.sh" | grep -v "container-recovery.sh" | crontab - 2>/dev/null || true
    
    # Add new cron jobs
    (crontab -l 2>/dev/null || true; cat <<EOF

# JSON2Excel - Docker Cleanup (daily at 2 AM)
0 2 * * * /usr/local/bin/docker-cleanup.sh >> /var/log/docker-cleanup.log 2>&1

# JSON2Excel - Container Recovery Check (every 5 minutes)
*/5 * * * * /usr/local/bin/container-recovery.sh oneshot >> /var/log/container-recovery.log 2>&1

EOF
    ) | crontab -
    
    echo_success "Cron jobs configured"
    crontab -l | grep -E "docker-cleanup|container-recovery"
}

###############################################################################
# Configure Logging
###############################################################################

setup_logging() {
    echo_info "Configuring centralized logging..."
    
    # Create rsyslog config for json2excel
    cat > /etc/rsyslog.d/30-json2excel.conf <<'EOF'
# JSON2Excel Application Logging

# Docker cleanup logs
:programname, isequal, "docker-cleanup" /var/log/docker-cleanup.log
& stop

# Container recovery logs
:programname, isequal, "container-recovery" /var/log/container-recovery.log
& stop

# System watchdog logs
:programname, isequal, "system-watchdog" /var/log/system-watchdog.log
& stop

# JSON2Excel service logs
:programname, isequal, "json2excel" /var/log/json2excel.log
& stop
EOF
    
    # Configure logrotate for our logs
    cat > /etc/logrotate.d/json2excel <<'EOF'
/var/log/docker-cleanup.log
/var/log/container-recovery.log
/var/log/system-watchdog.log
/var/log/json2excel.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    missingok
    create 0644 root root
    sharedscripts
    postrotate
        systemctl reload rsyslog > /dev/null 2>&1 || true
    endscript
}
EOF
    
    # Restart rsyslog
    systemctl restart rsyslog
    
    echo_success "Logging configured"
}

###############################################################################
# Configure Journald
###############################################################################

configure_journald() {
    echo_info "Optimizing journald configuration..."
    
    # Backup original config
    cp /etc/systemd/journald.conf /etc/systemd/journald.conf.backup 2>/dev/null || true
    
    # Configure journald
    cat > /etc/systemd/journald.conf.d/json2excel.conf <<'EOF'
[Journal]
# Persistent storage
Storage=persistent

# Limit journal size
SystemMaxUse=500M
SystemKeepFree=1G
SystemMaxFileSize=100M

# Retention
MaxRetentionSec=7day

# Forward to syslog
ForwardToSyslog=yes

# Rate limiting
RateLimitIntervalSec=30s
RateLimitBurst=10000
EOF
    
    # Restart journald
    systemctl restart systemd-journald
    
    echo_success "Journald optimized"
}

###############################################################################
# Test Installation
###############################################################################

test_installation() {
    echo_info "Testing installation..."
    
    # Test docker cleanup script
    if /usr/local/bin/docker-cleanup.sh >> /tmp/test-cleanup.log 2>&1; then
        echo_success "Docker cleanup script: OK"
    else
        echo_warn "Docker cleanup script: Failed (non-critical)"
    fi
    
    # Test container recovery script
    if timeout 30 /usr/local/bin/container-recovery.sh oneshot >> /tmp/test-recovery.log 2>&1; then
        echo_success "Container recovery script: OK"
    else
        echo_warn "Container recovery script: Failed (non-critical)"
    fi
    
    # Test systemd services
    if systemctl is-enabled json2excel.service &>/dev/null; then
        echo_success "json2excel.service: Enabled"
    fi
    
    if systemctl is-enabled system-watchdog.service &>/dev/null; then
        echo_success "system-watchdog.service: Enabled"
    fi
    
    # Test cron jobs
    if crontab -l | grep -q "docker-cleanup"; then
        echo_success "Cron jobs: Configured"
    fi
    
    echo_success "Installation test completed"
}

###############################################################################
# Display Summary
###############################################################################

display_summary() {
    echo ""
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}  Installation Complete!${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo ""
    echo "📋 Installed Components:"
    echo ""
    echo "1. Scripts:"
    echo "   - /usr/local/bin/docker-cleanup.sh"
    echo "   - /usr/local/bin/container-recovery.sh"
    echo "   - /usr/local/bin/system-watchdog.sh"
    echo ""
    echo "2. Systemd Services:"
    echo "   - json2excel.service (application)"
    echo "   - system-watchdog.service (boot recovery)"
    echo ""
    echo "3. Cron Jobs:"
    echo "   - Docker cleanup: Daily at 2 AM"
    echo "   - Recovery check: Every 5 minutes"
    echo ""
    echo "4. Logging:"
    echo "   - /var/log/docker-cleanup.log"
    echo "   - /var/log/container-recovery.log"
    echo "   - /var/log/system-watchdog.log"
    echo "   - /var/log/json2excel.log"
    echo "   - journalctl -u json2excel"
    echo ""
    echo "🔧 Management Commands:"
    echo ""
    echo "  # Service control"
    echo "  systemctl status json2excel"
    echo "  systemctl restart json2excel"
    echo ""
    echo "  # View logs"
    echo "  tail -f /var/log/docker-cleanup.log"
    echo "  tail -f /var/log/container-recovery.log"
    echo "  journalctl -u json2excel -f"
    echo ""
    echo "  # Manual execution"
    echo "  /usr/local/bin/docker-cleanup.sh"
    echo "  /usr/local/bin/container-recovery.sh oneshot"
    echo ""
    echo "  # Check cron jobs"
    echo "  crontab -l"
    echo ""
    echo "✅ System is now production-ready with:"
    echo "   - Automated cleanup"
    echo "   - Self-healing containers"
    echo "   - Auto-recovery on reboot"
    echo "   - Centralized logging"
    echo ""
}

###############################################################################
# Main
###############################################################################

main() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}  JSON2Excel Professional Setup${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""
    
    check_prerequisites
    install_scripts
    install_systemd_services
    setup_cron_jobs
    setup_logging
    configure_journald
    test_installation
    display_summary
}

# Run
main "$@"
