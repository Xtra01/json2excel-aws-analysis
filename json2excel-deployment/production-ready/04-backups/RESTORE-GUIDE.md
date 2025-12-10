# Backup ve Restore Rehberi

## 📦 Backup Sistemi

### Otomatik Backup

**Zamanlama:** Her gün 03:00 (crontab)  
**Saklama:** 7 gün (otomatik rotasyon)  
**Lokasyon:** `/opt/json2excel/backups/`

**Backup İçeriği:**
1. **App Source Code** (~2MB) - Node.js uygulama kodu
2. **Docker Image** (~45MB) - Built production image
3. **Redis Data** (varies) - Cache ve session data
4. **Config Files** (~10KB) - nginx.conf, docker-compose.yml, Dockerfile
5. **Uploads** (varies) - Kullanıcı yüklediği dosyalar

### Manuel Backup

```bash
# SSH ile sunucuya bağlan
ssh root@31.56.214.200

# Backup script çalıştır
/usr/local/bin/json2excel-backup.sh

# Sonuç kontrol
ls -lh /opt/json2excel/backups/*/*
tail -20 /var/log/json2excel-backup.log
```

### Backup Dosyaları

```
/opt/json2excel/backups/
├── app/
│   ├── app-20251210-000734.tar.gz           # Source code
│   └── docker-image-20251210-000734.tar.gz  # Docker image
├── redis/
│   └── redis-20251210-000747.rdb            # Redis dump
├── config/
│   └── config-20251210-000747.tar.gz        # Configs
└── uploads/
    └── uploads-20251210-000747.tar.gz       # User files
```

### Backup Verification

```bash
# Backup boyutlarını kontrol
du -sh /opt/json2excel/backups/*

# En son backupları listele
find /opt/json2excel/backups -type f -mtime -1 -ls

# Backup log kontrol
tail -50 /var/log/json2excel-backup.log | grep "✅"
```

---

## 🔄 Restore İşlemleri

### 1. Tam Restore (Full System)

**Kullanım:** Sistem tamamen çöktü, sıfırdan kurulum gerekiyor

```bash
# SSH bağlantısı
ssh root@31.56.214.200

# Mevcut servisleri durdur
cd /opt/json2excel
docker compose down

# En son backup'ı bul
LATEST_APP=$(ls -t backups/app/app-*.tar.gz | head -1)
LATEST_CONFIG=$(ls -t backups/config/config-*.tar.gz | head -1)
LATEST_UPLOADS=$(ls -t backups/uploads/uploads-*.tar.gz | head -1)

echo "Restore edilecek backuplar:"
echo "  App: $LATEST_APP"
echo "  Config: $LATEST_CONFIG"
echo "  Uploads: $LATEST_UPLOADS"

# App restore
cd /opt/json2excel
rm -rf app/*
tar -xzf "$LATEST_APP" -C /opt/json2excel/

# Config restore
tar -xzf "$LATEST_CONFIG" -C /opt/json2excel/

# Uploads restore
rm -rf /var/lib/json2excel/uploads/*
tar -xzf "$LATEST_UPLOADS" -C /var/lib/json2excel/

# SELinux context
chcon -Rt svirt_sandbox_file_t /opt/json2excel/app

# Permissions
chown -R 1001:1001 /var/lib/json2excel/uploads

# Rebuild ve start
docker compose up -d --build

# Health check
sleep 30
/usr/local/bin/json2excel-healthcheck.sh
```

**Beklenen süre:** 10-15 dakika (build dahil)

---

### 2. App-Only Restore

**Kullanım:** Sadece uygulama kodu bozuldu

```bash
cd /opt/json2excel
docker compose stop app

# Son app backup
LATEST_APP=$(ls -t backups/app/app-*.tar.gz | head -1)

# App restore
rm -rf app/*
tar -xzf "$LATEST_APP"

# SELinux
chcon -Rt svirt_sandbox_file_t app/

# Rebuild
docker compose up -d --build app

# Test
curl -I http://localhost/
```

**Beklenen süre:** 3-5 dakika

---

### 3. Config-Only Restore

**Kullanım:** Nginx veya docker-compose.yml bozuldu

```bash
cd /opt/json2excel
docker compose stop nginx

# Son config backup
LATEST_CONFIG=$(ls -t backups/config/config-*.tar.gz | head -1)

# Config restore
tar -xzf "$LATEST_CONFIG"

# Nginx config test
docker exec json2excel-nginx nginx -t || echo "Nginx down, starting..."

# Restart
docker compose up -d nginx

# Test
curl -I http://localhost/
```

**Beklenen süre:** 1 dakika

---

### 4. Redis Data Restore

**Kullanım:** Cache veya session data kayboldu

```bash
# Redis stop
docker compose stop redis

# Son redis backup
LATEST_REDIS=$(ls -t backups/redis/redis-*.rdb | head -1)

# Redis data restore
docker cp "$LATEST_REDIS" json2excel-redis:/data/dump.rdb

# Restart
docker compose start redis

# Verify
docker exec json2excel-redis redis-cli PING
# Expected: PONG
```

**Beklenen süre:** 30 saniye

---

### 5. Uploads Restore

**Kullanım:** Kullanıcı dosyaları kayboldu

```bash
# Son uploads backup
LATEST_UPLOADS=$(ls -t backups/uploads/uploads-*.tar.gz | head -1)

# Uploads restore
rm -rf /var/lib/json2excel/uploads/*
tar -xzf "$LATEST_UPLOADS" -C /var/lib/json2excel/

# Permissions
chown -R 1001:1001 /var/lib/json2excel/uploads

# Verify
ls -la /var/lib/json2excel/uploads/
```

**Beklenen süre:** 1-2 dakika

---

### 6. Docker Image Restore

**Kullanım:** Image silindi, hızlı restore gerekli

```bash
# Son image backup
LATEST_IMAGE=$(ls -t backups/app/docker-image-*.tar.gz | head -1)

# Image load
gunzip -c "$LATEST_IMAGE" | docker load

# Verify
docker images | grep json2excel

# Start
docker compose up -d
```

**Beklenen süre:** 2-3 dakika (build gerekmez)

---

## 🎯 Restore Senaryoları

### Senaryo 1: Sunucu Çöktü, Yeniden Kuruluyor

**Adımlar:**

1. **Yeni sunucu hazırlığı:**
```bash
# Gerekli paketler
dnf install -y epel-release
dnf install -y podman git

# Docker compose
curl -SL https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
```

2. **Backup'ları transfer et:**
```powershell
# Yerel makineden
scp -r root@OLD_SERVER:/opt/json2excel/backups ./
scp -r ./backups root@NEW_SERVER:/opt/json2excel/
```

3. **Full restore çalıştır** (yukarıdaki Tam Restore adımları)

4. **Monitoring ve backup setup:**
```bash
# Backup sistemi kur
bash /path/to/setup-backup-system.sh

# Monitoring kur
bash /path/to/setup-monitoring.sh
```

---

### Senaryo 2: Yanlış Deployment, Önceki Versiyona Dön

```bash
# Stop mevcut
cd /opt/json2excel
docker compose down

# Belirli bir tarihli backup'ı restore et
# Örnek: 2 gün önceki backup
tar -xzf backups/app/app-20251208-030000.tar.gz
tar -xzf backups/config/config-20251208-030000.tar.gz

# Rebuild
docker compose up -d --build

# Test
curl -I https://json2excel.devtestenv.org
```

---

### Senaryo 3: Sadece Database Corruption

```bash
# Redis data corrupt
docker compose stop redis

# En son sağlıklı dump'ı restore
HEALTHY_DUMP=$(ls -t backups/redis/redis-*.rdb | sed -n '2p')  # 2. en yeni
docker cp "$HEALTHY_DUMP" json2excel-redis:/data/dump.rdb

# Restart
docker compose start redis
```

---

## 📋 Backup Best Practices

### 1. Düzenli Test Et

```bash
# Ayda bir restore testi
# Test sunucusunda:
tar -tzf backups/app/app-latest.tar.gz
tar -tzf backups/config/config-latest.tar.gz
# Dosyalar listelenmeli
```

### 2. Off-Site Backup

```bash
# Backup'ları uzak lokasyona kopyala
rsync -avz /opt/json2excel/backups/ \
  root@backup-server:/backups/json2excel/

# Veya cloud storage
rclone sync /opt/json2excel/backups/ s3:my-bucket/json2excel-backups/
```

### 3. Backup Monitoring

```bash
# Backup yaşını kontrol
LAST_BACKUP=$(find /opt/json2excel/backups/app -name "*.tar.gz" -mtime -1 | wc -l)
if [ "$LAST_BACKUP" -eq 0 ]; then
  echo "⚠️  24 saatten eski backup yok!"
fi
```

### 4. Retention Policy

```bash
# Özel dosyalar için uzun saklama
# Örnek: Aylık backupları 1 yıl sakla
mkdir -p /opt/json2excel/backups/monthly/

# Her ayın 1'inde
if [ $(date +%d) -eq 01 ]; then
  cp backups/app/app-$(date +%Y%m%d-030000).tar.gz \
     backups/monthly/app-$(date +%Y%m).tar.gz
fi
```

---

## 🔐 Backup Security

### Encryption (Opsiyonel)

```bash
# Backup'ları encrypt et
tar -czf - backups/app/app-*.tar.gz | \
  openssl enc -aes-256-cbc -salt -out backup-encrypted.tar.gz.enc

# Decrypt
openssl enc -aes-256-cbc -d -in backup-encrypted.tar.gz.enc | \
  tar -xzf -
```

### Access Control

```bash
# Backup dizini sadece root erişebilir
chmod 700 /opt/json2excel/backups
chown -R root:root /opt/json2excel/backups
```

---

## 📊 Backup Monitoring Dashboard

### Backup Status Script

```bash
#!/bin/bash
echo "=== BACKUP STATUS ==="
echo ""

# Son backuplar
echo "📦 Son Backuplar:"
find /opt/json2excel/backups -name "*.tar.gz" -o -name "*.rdb" | \
  xargs ls -lth | head -10

echo ""
echo "💾 Backup Boyutları:"
du -sh /opt/json2excel/backups/*

echo ""
echo "⏰ Son Backup Zamanı:"
stat -c "%y" $(find /opt/json2excel/backups -name "*.tar.gz" | sort | tail -1)

echo ""
echo "📊 Toplam Backup Sayısı:"
find /opt/json2excel/backups -type f | wc -l

echo ""
echo "🕐 7 Günden Eski Backuplar:"
find /opt/json2excel/backups -type f -mtime +7 | wc -l
```

Kaydet: `/usr/local/bin/backup-status.sh`

---

## 🆘 Emergency Recovery

### Quickstart Recovery Commands

```bash
# 1. En son backupları göster
ls -lth /opt/json2excel/backups/*/ | head -15

# 2. Full restore (tek komut)
cd /opt/json2excel && \
docker compose down && \
tar -xzf $(ls -t backups/app/app-*.tar.gz | head -1) && \
tar -xzf $(ls -t backups/config/config-*.tar.gz | head -1) && \
chcon -Rt svirt_sandbox_file_t app/ && \
docker compose up -d --build

# 3. Health check
sleep 30 && /usr/local/bin/json2excel-healthcheck.sh
```

---

## 📞 Restore Sonrası Kontroller

```bash
# ✅ Containerlar çalışıyor mu?
docker ps | grep json2excel

# ✅ Web service çalışıyor mu?
curl -I http://localhost/
curl -I https://localhost/

# ✅ App response doğru mu?
curl https://localhost/ | grep "JSON to Excel"

# ✅ Health check pass mi?
/usr/local/bin/json2excel-healthcheck.sh

# ✅ Logs normal mi?
docker compose logs --tail 50

# ✅ Resources normal mi?
docker stats --no-stream
```

---

## 📚 İlgili Dokümantasyon

- **Backup Setup:** `01-scripts/setup-backup-system.sh`
- **Troubleshooting:** `03-docs/TROUBLESHOOTING.md`
- **Management:** `03-docs/MANAGEMENT-GUIDE.md`
