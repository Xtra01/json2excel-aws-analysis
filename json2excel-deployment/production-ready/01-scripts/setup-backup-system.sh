#!/bin/bash

# JSON to Excel Otomatik Backup Sistemi
# Günlük otomatik yedekleme ve rotasyon

set -e

echo "=== OTOMATIK BACKUP SİSTEMİ KURULUMU ==="
echo ""

# Backup dizinleri
BACKUP_ROOT="/opt/json2excel/backups"
APP_BACKUP="$BACKUP_ROOT/app"
DB_BACKUP="$BACKUP_ROOT/redis"
CONFIG_BACKUP="$BACKUP_ROOT/config"
UPLOADS_BACKUP="$BACKUP_ROOT/uploads"

# Dizinleri oluştur
echo "📁 Backup dizinleri oluşturuluyor..."
mkdir -p "$APP_BACKUP" "$DB_BACKUP" "$CONFIG_BACKUP" "$UPLOADS_BACKUP"

# Backup script
cat > /usr/local/bin/json2excel-backup.sh << 'BACKUP_SCRIPT'
#!/bin/bash

# Yedekleme tarihi
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_ROOT="/opt/json2excel/backups"
PROJECT_DIR="/opt/json2excel"

# Log fonksiyonu
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/json2excel-backup.log
}

log "=== Backup başlatıldı ==="

# 1. Uygulama kaynak kodu
log "📦 App source code yedekleniyor..."
tar -czf "$BACKUP_ROOT/app/app-$DATE.tar.gz" \
    -C "$PROJECT_DIR" \
    --exclude='node_modules' \
    --exclude='.next' \
    --exclude='*.log' \
    app/ 2>/dev/null || log "⚠️  App backup warning"

# 2. Docker images
log "🐳 Docker images yedekleniyor..."
docker save json2excel-json2excel-app:latest | gzip > "$BACKUP_ROOT/app/docker-image-$DATE.tar.gz" 2>/dev/null || log "⚠️  Docker image backup warning"

# 3. Redis data (eğer varsa)
log "💾 Redis data yedekleniyor..."
if docker ps --format '{{.Names}}' | grep -q 'json2excel-redis'; then
    docker exec json2excel-redis redis-cli SAVE > /dev/null 2>&1 || true
    docker cp json2excel-redis:/data/dump.rdb "$BACKUP_ROOT/redis/redis-$DATE.rdb" 2>/dev/null || log "⚠️  Redis backup warning"
fi

# 4. Nginx config
log "⚙️ Configuration yedekleniyor..."
tar -czf "$BACKUP_ROOT/config/config-$DATE.tar.gz" \
    -C "$PROJECT_DIR" \
    config/ docker-compose.yml Dockerfile 2>/dev/null || log "⚠️  Config backup warning"

# 5. Uploads (eğer varsa)
log "📁 Uploads yedekleniyor..."
if [ -d "/var/lib/json2excel/uploads" ]; then
    tar -czf "$BACKUP_ROOT/uploads/uploads-$DATE.tar.gz" \
        -C /var/lib/json2excel uploads/ 2>/dev/null || log "⚠️  Uploads backup warning"
fi

# 6. Eski backupları temizle (7 günden eski)
log "🧹 Eski backuplar temizleniyor (>7 gün)..."
find "$BACKUP_ROOT" -type f -mtime +7 -name "*.tar.gz" -delete 2>/dev/null || true
find "$BACKUP_ROOT" -type f -mtime +7 -name "*.rdb" -delete 2>/dev/null || true

# Backup boyutu hesapla
TOTAL_SIZE=$(du -sh "$BACKUP_ROOT" | cut -f1)
log "✅ Backup tamamlandı! Toplam boyut: $TOTAL_SIZE"
log "📍 Backup dizini: $BACKUP_ROOT"

# Backup summary
echo "=== BACKUP ÖZET ===" >> /var/log/json2excel-backup.log
ls -lh "$BACKUP_ROOT"/*/*.{tar.gz,rdb} 2>/dev/null | tail -10 >> /var/log/json2excel-backup.log
echo "" >> /var/log/json2excel-backup.log

BACKUP_SCRIPT

chmod +x /usr/local/bin/json2excel-backup.sh

# Crontab ekle - Her gün saat 03:00'de backup
echo "⏰ Crontab yapılandırılıyor (günlük 03:00)..."
(crontab -l 2>/dev/null | grep -v 'json2excel-backup'; echo "0 3 * * * /usr/local/bin/json2excel-backup.sh") | crontab -

# İlk backup'ı çalıştır
echo "🚀 İlk backup çalıştırılıyor..."
/usr/local/bin/json2excel-backup.sh

echo ""
echo "✅ BACKUP SİSTEMİ KURULDU!"
echo ""
echo "📋 Backup Bilgileri:"
echo "   • Backup dizini: $BACKUP_ROOT"
echo "   • Zamanlama: Her gün 03:00"
echo "   • Saklama süresi: 7 gün"
echo "   • Log dosyası: /var/log/json2excel-backup.log"
echo ""
echo "🔧 Yönetim Komutları:"
echo "   • Manuel backup: /usr/local/bin/json2excel-backup.sh"
echo "   • Backup kontrol: ls -lh /opt/json2excel/backups/*/*"
echo "   • Log görüntüle: tail -f /var/log/json2excel-backup.log"
echo "   • Crontab kontrol: crontab -l | grep backup"
echo ""
