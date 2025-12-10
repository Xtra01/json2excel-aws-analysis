# Production Automation & Monitoring Guide

## 🎯 Genel Bakış

Bu döküman, JSON2Excel production ortamında kurulu olan tüm otomasyon sistemlerini açıklar.

## 📋 Kurulu Sistemler

### 1. Docker Cleanup (Günlük Temizlik)

**Script:** `/usr/local/bin/docker-cleanup.sh`  
**Çalışma Zamanı:** Her gün 02:00  
**Log:** `/var/log/docker-cleanup.log`

**Görevleri:**
- Kullanılmayan container'ları sil
- Dangling image'leri temizle
- 7 günden eski image'leri sil
- Kullanılmayan volume'leri temizle
- Kullanılmayan network'leri temizle
- Build cache'i temizle
- System log'ları temizle (journald 7 gün)
- Container log'ları rotate et (100MB üzeri)
- Disk kullanım raporu oluştur

**Manuel Çalıştırma:**
```bash
/usr/local/bin/docker-cleanup.sh
```

**Log İnceleme:**
```bash
tail -f /var/log/docker-cleanup.log
```

---

### 2. Container Recovery (Otomatik İyileştirme)

**Script:** `/usr/local/bin/container-recovery.sh`  
**Çalışma Zamanı:** Her 5 dakikada bir  
**Log:** `/var/log/container-recovery.log`

**Görevleri:**
- Container sağlık kontrolü (healthcheck)
- Web servis kontrolü (HTTP 200 check)
- Başarısız container'ları yeniden başlat (max 3 deneme)
- Çoklu başarısızlıkta full system recovery
- Alert gönderimi (webhook varsa)

**Kurtarma Senaryoları:**

1. **Tek Container Başarısız:**
   - 3 kez restart dene
   - Her deneme arasında 10 saniye bekle
   - Başarısız olursa full recovery'ye geç

2. **Çoklu Container Başarısız:**
   - Doğrudan full system recovery
   - Docker compose restart
   - Web servis doğrulaması

3. **Full System Recovery:**
   - Tüm container'ları restart et
   - 10 saniye bekle ve web check
   - Başarısız olursa rebuild yap

**Manuel Çalıştırma:**
```bash
# Tek seferlik kontrol
/usr/local/bin/container-recovery.sh oneshot

# Daemon mode (sürekli monitoring)
/usr/local/bin/container-recovery.sh daemon
```

**Log İnceleme:**
```bash
tail -f /var/log/container-recovery.log
```

---

### 3. System Watchdog (Reboot Koruması)

**Script:** `/usr/local/bin/system-watchdog.sh`  
**Service:** `system-watchdog.service`  
**Çalışma Zamanı:** Boot sonrası otomatik  
**Log:** `/var/log/system-watchdog.log`, `journalctl -u system-watchdog`

**Görevleri:**
- Server reboot tespiti (uptime < 10 dakika)
- Docker daemon hazır olmasını bekle
- Container'ları otomatik başlat
- Sağlık kontrolü ve recovery
- Boot notification gönder

**Boot Senaryosu:**
1. Server açılıyor
2. Systemd network-online.target bekler
3. System watchdog devreye girer
4. Docker daemon hazır mı kontrol eder (max 5 dakika)
5. Container'ları başlatır
6. 30 saniye sonra sağlık kontrolü
7. Sorun varsa recovery tetikler

**Service Kontrolü:**
```bash
systemctl status system-watchdog.service
systemctl enable system-watchdog.service
```

**Log İnceleme:**
```bash
journalctl -u system-watchdog -f
```

---

### 4. JSON2Excel Service (Container Orchestration)

**Service:** `json2excel.service`  
**Compose File:** `/opt/json2excel/docker-compose.yml`  
**Log:** `journalctl -u json2excel`

**Görevleri:**
- Container stack yönetimi
- Systemd entegrasyonu
- Restart policy (on-failure)
- Auto-enable on boot

**Service Komutları:**
```bash
# Durum kontrolü
systemctl status json2excel

# Başlat
systemctl start json2excel

# Durdur
systemctl stop json2excel

# Yeniden başlat
systemctl restart json2excel

# Reload (graceful restart)
systemctl reload json2excel

# Boot'ta otomatik başlat
systemctl enable json2excel
```

---

## 📊 Monitoring ve Logging

### Centralized Logging

**Rsyslog Configuration:** `/etc/rsyslog.d/30-json2excel.conf`

Tüm uygulama log'ları merkezi olarak yönetilir:
- `docker-cleanup` → `/var/log/docker-cleanup.log`
- `container-recovery` → `/var/log/container-recovery.log`
- `system-watchdog` → `/var/log/system-watchdog.log`
- `json2excel` → `/var/log/json2excel.log`

### Logrotate Configuration

**File:** `/etc/logrotate.d/json2excel`

**Ayarlar:**
- Rotation: Daily
- Retention: 14 gün
- Compression: gzip
- Post-rotate: rsyslog reload

### Journald Configuration

**File:** `/etc/systemd/journald.conf.d/json2excel.conf`

**Ayarlar:**
- Storage: Persistent
- Max Size: 500MB
- Retention: 7 gün
- Forward to syslog: Yes

**Journald Komutları:**
```bash
# Tüm json2excel logları
journalctl -u json2excel -f

# System watchdog logları
journalctl -u system-watchdog -f

# Son 100 satır
journalctl -u json2excel -n 100

# Bugünün logları
journalctl -u json2excel --since today

# Belirli zaman aralığı
journalctl -u json2excel --since "2025-12-10 00:00:00" --until "2025-12-10 23:59:59"
```

---

## 🔔 Alert Sistemi

### Webhook Configuration

Container recovery ve watchdog scriptleri webhook desteği içerir.

**Environment Variable:**
```bash
export ALERT_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
# veya
export ALERT_WEBHOOK="https://discord.com/api/webhooks/YOUR/WEBHOOK"
```

**Alert Türleri:**
- Container failure (critical)
- System recovery initiated (warning)
- System recovered (info)
- Low disk space (warning)

**Alert Payload:**
```json
{
  "title": "Container Failure",
  "message": "Container json2excel-app failed to recover",
  "severity": "critical",
  "host": "31-56-214-200.verisunucu.net",
  "timestamp": "2025-12-10T01:20:05Z"
}
```

---

## 📈 Performance Metrics

### Disk Usage Monitoring

```bash
# Current usage
df -h /

# Docker disk usage
docker system df

# Detailed breakdown
du -sh /var/lib/containers/storage
du -sh /opt/json2excel/backups
```

### Container Stats

```bash
# Real-time stats
docker stats

# Container resource usage
docker ps --format "table {{.Names}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Container logs size
docker ps -q | xargs -I {} docker inspect --format='{{.Name}} {{.LogPath}}' {} | while read name path; do echo "$name: $(du -sh $path 2>/dev/null || echo 'N/A')"; done
```

---

## 🛠️ Troubleshooting

### Docker Cleanup Sorunları

**Problem:** Cleanup çalışmıyor
```bash
# Manual test
/usr/local/bin/docker-cleanup.sh

# Log kontrol
tail -100 /var/log/docker-cleanup.log

# Cron job kontrol
crontab -l | grep cleanup
```

**Problem:** Çok fazla yer kaplıyor
```bash
# Agresif temizlik
docker system prune -a -f --volumes

# Log temizliği
journalctl --vacuum-time=1d
```

### Container Recovery Sorunları

**Problem:** Recovery sürekli tetikleniyor
```bash
# Container health check
docker inspect json2excel-app --format='{{.State.Health.Status}}'

# Container logs
docker logs json2excel-app --tail 100

# Manuel recovery
/usr/local/bin/container-recovery.sh oneshot
```

**Problem:** Recovery başarısız oluyor
```bash
# Full rebuild
cd /opt/json2excel
docker compose down
docker compose up -d --build

# Logs kontrol
tail -f /var/log/container-recovery.log
```

### System Watchdog Sorunları

**Problem:** Boot sonrası container'lar başlamıyor
```bash
# Service status
systemctl status system-watchdog.service

# Logs
journalctl -u system-watchdog -n 50

# Manuel trigger
/usr/local/bin/system-watchdog.sh
```

**Problem:** Lock file hatası
```bash
# Stale lock temizle
rm -f /var/run/system-watchdog.lock

# Service restart
systemctl restart system-watchdog
```

---

## 🔧 Maintenance Commands

### Daily Operations

```bash
# Health check
/usr/local/bin/container-recovery.sh oneshot

# Disk usage check
df -h / && docker system df

# Container status
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Size}}"

# Log review
tail -20 /var/log/docker-cleanup.log
tail -20 /var/log/container-recovery.log
```

### Weekly Operations

```bash
# Full cleanup
/usr/local/bin/docker-cleanup.sh

# Backup verification
ls -lh /opt/json2excel/backups/

# Service status
systemctl status json2excel system-watchdog

# Log rotation check
ls -lh /var/log/docker-cleanup.log*
```

### Monthly Operations

```bash
# Review metrics
journalctl -u json2excel --since "1 month ago" | grep -i error

# Cleanup old logs
journalctl --vacuum-time=30d

# Review cron jobs
crontab -l

# Check service status
systemctl list-units --type=service --state=failed
```

---

## 📝 Configuration Files

| File | Purpose | Location |
|------|---------|----------|
| `docker-cleanup.sh` | Cleanup script | `/usr/local/bin/` |
| `container-recovery.sh` | Recovery script | `/usr/local/bin/` |
| `system-watchdog.sh` | Watchdog script | `/usr/local/bin/` |
| `json2excel.service` | Systemd service | `/etc/systemd/system/` |
| `system-watchdog.service` | Systemd service | `/etc/systemd/system/` |
| `30-json2excel.conf` | Rsyslog config | `/etc/rsyslog.d/` |
| `json2excel` | Logrotate config | `/etc/logrotate.d/` |
| `json2excel.conf` | Journald config | `/etc/systemd/journald.conf.d/` |

---

## 🎓 Best Practices

### Do's ✅

- Her değişiklikten sonra servisleri test et
- Log dosyalarını düzenli kontrol et
- Disk kullanımını izle
- Backup'ları düzenli doğrula
- Alert webhook'u yapılandır
- Cron job'ları düzenli kontrol et

### Don'ts ❌

- Production'da deneysel değişiklik yapma
- Log rotation'ı devre dışı bırakma
- Recovery script'i sürekli iptal etme
- Systemd service'leri manuel docker komutlarıyla karıştırma
- Lock file'ları manuel silme (gerekmedikçe)

---

## 🔗 Related Documentation

- [DEPLOYMENT-COMPLETE-REPORT.md](../DEPLOYMENT-COMPLETE-REPORT.md) - Full deployment guide
- [MANAGEMENT-GUIDE.md](./MANAGEMENT-GUIDE.md) - Daily operations
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - Problem solving
- [RESTORE-GUIDE.md](../04-backups/RESTORE-GUIDE.md) - Backup/restore procedures

---

**Last Updated:** 2025-12-10  
**Version:** 1.0.0  
**Status:** Production Ready ✅
