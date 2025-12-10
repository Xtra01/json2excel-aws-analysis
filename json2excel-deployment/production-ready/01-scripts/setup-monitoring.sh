#!/bin/bash

# JSON to Excel Monitoring ve Health Check Sistemi

set -e

echo "=== MONİTORİNG SİSTEMİ KURULUMU ==="
echo ""

# Health check script
cat > /usr/local/bin/json2excel-healthcheck.sh << 'HEALTHCHECK_SCRIPT'
#!/bin/bash

# Log fonksiyonu
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/json2excel-health.log
}

# Alert fonksiyonu (opsiyonel - email için exim gerekir)
alert() {
    local subject="$1"
    local message="$2"
    log "🚨 ALERT: $subject - $message"
    # Email gönderimi için: echo "$message" | mail -s "$subject" admin@devtestenv.org
}

# Container health check
check_containers() {
    log "🐳 Container kontrolü..."
    
    CONTAINERS=("json2excel-app" "json2excel-nginx" "json2excel-redis")
    ALL_HEALTHY=true
    
    for container in "${CONTAINERS[@]}"; do
        if docker ps --format '{{.Names}}' | grep -q "^$container$"; then
            STATUS=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null)
            if [ "$STATUS" != "running" ]; then
                alert "Container Down" "$container is $STATUS"
                ALL_HEALTHY=false
            else
                log "  ✅ $container: running"
            fi
        else
            alert "Container Missing" "$container not found"
            ALL_HEALTHY=false
        fi
    done
    
    return $([ "$ALL_HEALTHY" = true ] && echo 0 || echo 1)
}

# HTTP/HTTPS health check
check_web() {
    log "🌐 Web service kontrolü..."
    
    # HTTP redirect check
    HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' http://localhost/ 2>/dev/null)
    if [ "$HTTP_CODE" != "301" ]; then
        alert "HTTP Redirect Failed" "Expected 301, got $HTTP_CODE"
        return 1
    fi
    log "  ✅ HTTP redirect: $HTTP_CODE"
    
    # HTTPS check
    HTTPS_CODE=$(curl -k -s -o /dev/null -w '%{http_code}' https://localhost/ 2>/dev/null)
    if [ "$HTTPS_CODE" != "200" ]; then
        alert "HTTPS Failed" "Expected 200, got $HTTPS_CODE"
        return 1
    fi
    log "  ✅ HTTPS response: $HTTPS_CODE"
    
    # Response time check (< 5 saniye)
    RESPONSE_TIME=$(curl -k -s -o /dev/null -w '%{time_total}' https://localhost/ 2>/dev/null)
    RESPONSE_MS=$(echo "$RESPONSE_TIME * 1000" | bc | cut -d'.' -f1)
    
    if [ "$RESPONSE_MS" -gt 5000 ]; then
        alert "Slow Response" "Response time: ${RESPONSE_MS}ms"
    fi
    log "  ✅ Response time: ${RESPONSE_MS}ms"
    
    return 0
}

# Disk space check
check_disk() {
    log "💾 Disk kullanımı kontrolü..."
    
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [ "$DISK_USAGE" -gt 85 ]; then
        alert "Disk Space Critical" "Disk usage: ${DISK_USAGE}%"
        return 1
    elif [ "$DISK_USAGE" -gt 70 ]; then
        log "  ⚠️  Disk usage: ${DISK_USAGE}% (warning)"
    else
        log "  ✅ Disk usage: ${DISK_USAGE}%"
    fi
    
    return 0
}

# Memory check
check_memory() {
    log "🧠 Memory kullanımı kontrolü..."
    
    MEM_USAGE=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100}')
    
    if [ "$MEM_USAGE" -gt 90 ]; then
        alert "Memory Critical" "Memory usage: ${MEM_USAGE}%"
        return 1
    elif [ "$MEM_USAGE" -gt 80 ]; then
        log "  ⚠️  Memory usage: ${MEM_USAGE}% (warning)"
    else
        log "  ✅ Memory usage: ${MEM_USAGE}%"
    fi
    
    return 0
}

# Docker logs error check
check_logs() {
    log "📋 Log kontrolü (son 5 dakika)..."
    
    ERROR_COUNT=$(docker compose -f /opt/json2excel/docker-compose.yml logs --since 5m 2>/dev/null | grep -iE '(error|fatal|exception)' | wc -l)
    
    if [ "$ERROR_COUNT" -gt 10 ]; then
        alert "High Error Rate" "Found $ERROR_COUNT errors in last 5 minutes"
        docker compose -f /opt/json2excel/docker-compose.yml logs --tail 20 >> /var/log/json2excel-health.log
    elif [ "$ERROR_COUNT" -gt 0 ]; then
        log "  ⚠️  Errors found: $ERROR_COUNT"
    else
        log "  ✅ No critical errors"
    fi
}

# SSL certificate expiry check
check_ssl() {
    log "🔒 SSL sertifika kontrolü..."
    
    if [ -f "/opt/json2excel/config/ssl/origin-cert.pem" ]; then
        EXPIRY_DATE=$(openssl x509 -in /opt/json2excel/config/ssl/origin-cert.pem -noout -enddate 2>/dev/null | cut -d= -f2)
        EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s 2>/dev/null || echo "")
        
        if [ -n "$EXPIRY_EPOCH" ]; then
            CURRENT_EPOCH=$(date +%s)
            DAYS_LEFT=$(( ($EXPIRY_EPOCH - $CURRENT_EPOCH) / 86400 ))
            
            if [ "$DAYS_LEFT" -lt 30 ]; then
                alert "SSL Expiring Soon" "Certificate expires in $DAYS_LEFT days"
            else
                log "  ✅ SSL valid for $DAYS_LEFT days"
            fi
        fi
    else
        log "  ⚠️  SSL certificate not found (using self-signed)"
    fi
}

# Ana health check
log "=== Health Check Başlatıldı ==="

FAILED=0

check_containers || FAILED=$((FAILED+1))
check_web || FAILED=$((FAILED+1))
check_disk || FAILED=$((FAILED+1))
check_memory || FAILED=$((FAILED+1))
check_logs
check_ssl

if [ "$FAILED" -eq 0 ]; then
    log "✅ Tüm kontroller başarılı"
else
    log "❌ $FAILED kontrol başarısız"
fi

log "=== Health Check Tamamlandı ==="
echo ""

exit $FAILED

HEALTHCHECK_SCRIPT

chmod +x /usr/local/bin/json2excel-healthcheck.sh

# Crontab ekle - Her 5 dakikada health check
echo "⏰ Health check crontab yapılandırılıyor (5 dakikada bir)..."
(crontab -l 2>/dev/null | grep -v 'json2excel-healthcheck'; echo "*/5 * * * * /usr/local/bin/json2excel-healthcheck.sh") | crontab -

# Status script (manuel kontrol için)
cat > /usr/local/bin/json2excel-status.sh << 'STATUS_SCRIPT'
#!/bin/bash

echo "=== JSON TO EXCEL - STATUS RAPORU ==="
echo ""

echo "🐳 DOCKER CONTAINERS:"
docker ps --filter name=json2excel --format 'table {{.Names}}\t{{.Status}}\t{{Ports}}'
echo ""

echo "💾 RESOURCE KULLANIMI:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" --filter name=json2excel
echo ""

echo "📊 SYSTEM RESOURCES:"
echo "  CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)% kullanımda"
echo "  Memory: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
echo "  Disk: $(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 " kullanımda)"}')"
echo ""

echo "🌐 WEB SERVICE:"
HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' http://localhost/ 2>/dev/null)
HTTPS_CODE=$(curl -k -s -o /dev/null -w '%{http_code}' https://localhost/ 2>/dev/null)
RESPONSE_TIME=$(curl -k -s -o /dev/null -w '%{time_total}s' https://localhost/ 2>/dev/null)
echo "  HTTP: $HTTP_CODE"
echo "  HTTPS: $HTTPS_CODE"
echo "  Response Time: $RESPONSE_TIME"
echo ""

echo "🔒 SSL:"
if [ -f "/opt/json2excel/config/ssl/origin-cert.pem" ]; then
    EXPIRY=$(openssl x509 -in /opt/json2excel/config/ssl/origin-cert.pem -noout -enddate 2>/dev/null | cut -d= -f2)
    echo "  Certificate: Cloudflare Origin"
    echo "  Expires: $EXPIRY"
else
    echo "  Certificate: Self-signed (geliştirme)"
fi
echo ""

echo "📋 SON LOG SATIRLARI:"
docker compose -f /opt/json2excel/docker-compose.yml logs --tail 5 2>/dev/null
echo ""

echo "📁 BACKUP:"
LAST_BACKUP=$(ls -lt /opt/json2excel/backups/app/*.tar.gz 2>/dev/null | head -1 | awk '{print $6, $7, $8, $9}')
BACKUP_SIZE=$(du -sh /opt/json2excel/backups 2>/dev/null | cut -f1)
echo "  Son backup: $LAST_BACKUP"
echo "  Toplam boyut: $BACKUP_SIZE"
echo ""

echo "🔐 FAIL2BAN:"
fail2ban-client status sshd 2>/dev/null | grep -E '(Currently banned|Total banned)'
echo ""

STATUS_SCRIPT

chmod +x /usr/local/bin/json2excel-status.sh

# İlk health check
echo "🚀 İlk health check çalıştırılıyor..."
echo ""
/usr/local/bin/json2excel-healthcheck.sh

echo ""
echo "✅ MONİTORİNG SİSTEMİ KURULDU!"
echo ""
echo "📋 Monitoring Bilgileri:"
echo "   • Health check: Her 5 dakika"
echo "   • Health log: /var/log/json2excel-health.log"
echo "   • Alert log: /var/log/json2excel-health.log"
echo ""
echo "🔧 Yönetim Komutları:"
echo "   • Manuel health check: /usr/local/bin/json2excel-healthcheck.sh"
echo "   • Status görüntüle: /usr/local/bin/json2excel-status.sh"
echo "   • Health log: tail -f /var/log/json2excel-health.log"
echo "   • Crontab kontrol: crontab -l | grep healthcheck"
echo ""
