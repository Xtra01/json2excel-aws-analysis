# Sorun Giderme Rehberi

## 🚨 Yaygın Sorunlar ve Çözümleri

### 1. Container Çalışmıyor

**Semptom:**
```bash
docker ps
# json2excel-app görünmüyor
```

**Çözüm:**
```bash
# Logs kontrol
docker logs json2excel-app --tail 100

# Hatalar için kontrol
docker compose -f /opt/json2excel/docker-compose.yml logs | grep -i error

# Restart dene
docker compose -f /opt/json2excel/docker-compose.yml restart json2excel-app

# Çalışmazsa rebuild
cd /opt/json2excel
docker compose down
docker compose up -d --build
```

---

### 2. HTTPS Çalışmıyor (523 Error)

**Semptom:**
```
curl https://json2excel.devtestenv.org
# 523: Origin is unreachable
```

**Neden:**
- Nginx container down
- SSL sertifikası hatalı
- Port 443 kapalı

**Çözüm:**
```bash
# 1. Container kontrol
docker ps | grep nginx

# 2. Nginx logs
docker logs json2excel-nginx --tail 50

# 3. SSL dosyaları kontrol
ls -la /opt/json2excel/config/ssl/

# 4. Nginx config test
docker exec json2excel-nginx nginx -t

# 5. Port kontrol
ss -tlnp | grep :443

# 6. Restart
docker compose restart nginx
```

---

### 3. Yavaş Response (>5 saniye)

**Semptom:**
```bash
curl -w "@-" -o /dev/null -s https://json2excel.devtestenv.org <<< \
"time_total: %{time_total}s\n"
# time_total: 8.234s
```

**Neden:**
- High CPU/memory usage
- App container restart loop
- Disk I/O sorunları

**Çözüm:**
```bash
# 1. Resource kontrol
docker stats --no-stream

# 2. Container health
docker inspect json2excel-app --format='{{.State.Health.Status}}'

# 3. App logs
docker logs json2excel-app --tail 100 | grep -i error

# 4. Disk space
df -h /

# 5. Memory
free -h

# Gerekirse restart
docker compose restart
```

---

### 4. Build Hatası

**Semptom:**
```bash
docker compose build
# ERROR: failed to solve: process "/bin/sh -c npm run build" did not complete successfully
```

**Neden:**
- SELinux context sorunu
- TypeScript compilation error
- Yetersiz memory

**Çözüm:**
```bash
# 1. SELinux context fix
chcon -Rt svirt_sandbox_file_t /opt/json2excel/app

# 2. Broken files temizle
cd /opt/json2excel/app
find . -name "*.broken.*" -delete
find . -name "*.backup.*" -delete

# 3. Clean build
docker compose down
docker system prune -a
docker compose build --no-cache

# 4. Build logs kontrol
docker compose build 2>&1 | tee build.log
```

---

### 5. SSH Connection Refused

**Semptom:**
```powershell
ssh root@31.56.214.200
# Connection refused
```

**Neden:**
- SSH service down
- Firewall blocking
- Yanlış port

**Çözüm:**
```bash
# Sunucu panelinden console erişimi ile:

# 1. SSH service kontrol
systemctl status sshd

# 2. Başlatma
systemctl start sshd

# 3. Firewall kontrol
firewall-cmd --list-services

# 4. SSH port ekle
firewall-cmd --permanent --add-service=ssh
firewall-cmd --reload

# 5. SSH config test
sshd -t
```

---

### 6. Fail2ban Kendini Banladı

**Semptom:**
```
ssh root@31.56.214.200
# Connection refused (banned)
```

**Çözüm:**
```bash
# Sunucu panelinden console:

# 1. Ban kontrol
fail2ban-client status sshd

# 2. Kendi IP'ni unban
fail2ban-client set sshd unbanip YOUR_IP

# 3. Whitelist ekle
echo "ignoreip = 127.0.0.1/8 YOUR_IP" >> /etc/fail2ban/jail.d/sshd.local
systemctl restart fail2ban
```

---

### 7. Disk Dolu

**Semptom:**
```bash
df -h
# /dev/sda1  118G  112G  1.2G  99% /
```

**Çözüm:**
```bash
# 1. En büyük dosyaları bul
du -h / | sort -rh | head -20

# 2. Docker cleanup
docker system prune -a --volumes

# 3. Eski backupları temizle
find /opt/json2excel/backups -mtime +7 -delete

# 4. Log rotation kontrol
journalctl --vacuum-time=3d

# 5. Eski kernels temizle
dnf remove $(dnf repoquery --installonly --latest-limit=-2 -q)
```

---

### 8. Memory Leak

**Semptom:**
```bash
free -h
# Mem: 31G  29G  500M  (95% used)
```

**Çözüm:**
```bash
# 1. Hangi container memory kullanıyor
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}"

# 2. App container restart
docker compose restart json2excel-app

# 3. Redis cache temizle
docker exec json2excel-redis redis-cli FLUSHALL

# 4. Hala sorun varsa full restart
docker compose down
docker compose up -d
```

---

### 9. Nginx 502 Bad Gateway

**Semptom:**
```
curl https://json2excel.devtestenv.org
# 502 Bad Gateway
```

**Neden:**
- App container down
- Upstream connection failed
- App port değişmiş

**Çözüm:**
```bash
# 1. App container kontrol
docker ps | grep json2excel-app

# 2. App container başlat
docker compose start json2excel-app

# 3. App logs
docker logs json2excel-app

# 4. Nginx upstream kontrol
docker exec json2excel-nginx cat /etc/nginx/nginx.conf | grep upstream

# 5. Network kontrol
docker network inspect json2excel-deployment_default

# 6. Restart
docker compose restart
```

---

### 10. Backup Çalışmıyor

**Semptom:**
```bash
ls /opt/json2excel/backups/
# Boş veya eski tarihler
```

**Çözüm:**
```bash
# 1. Crontab kontrol
crontab -l | grep backup

# 2. Manuel backup test
/usr/local/bin/json2excel-backup.sh

# 3. Log kontrol
tail -f /var/log/json2excel-backup.log

# 4. Script permissions
chmod +x /usr/local/bin/json2excel-backup.sh

# 5. Cron service
systemctl status crond
```

---

### 11. Health Check Fail

**Semptom:**
```bash
/usr/local/bin/json2excel-healthcheck.sh
# ❌ 3 kontrol başarısız
```

**Çözüm:**
```bash
# 1. Hangi kontroller fail
tail -20 /var/log/json2excel-health.log

# 2. Her komponenti tek tek test
curl -I http://localhost/        # HTTP redirect
curl -I https://localhost/       # HTTPS
docker ps                        # Containers
df -h                            # Disk
free -h                          # Memory

# 3. Sorunlu servisi düzelt
# Örnek: HTTPS fail → nginx restart
docker compose restart nginx
```

---

### 12. SSL Certificate Expired

**Semptom:**
```bash
curl https://json2excel.devtestenv.org
# SSL certificate problem: certificate has expired
```

**Çözüm:**
```bash
# Cloudflare Origin Certificate kullanıyorsanız:
# Certificate 15 yıl geçerli, expiry olmamalı

# 1. Certificate kontrol
openssl x509 -in /opt/json2excel/config/ssl/origin-cert.pem -noout -dates

# 2. Yeni certificate al
# Cloudflare Dashboard → SSL/TLS → Origin Server
# Create Certificate → Download

# 3. Yükle
scp origin-cert.pem root@31.56.214.200:/opt/json2excel/config/ssl/
scp private-key.key root@31.56.214.200:/opt/json2excel/config/ssl/

# 4. Permissions
chmod 644 /opt/json2excel/config/ssl/origin-cert.pem
chmod 600 /opt/json2excel/config/ssl/private-key.key

# 5. Nginx reload
docker compose restart nginx
```

---

## 🔍 Diagnostic Commands

### Quick Health Check
```bash
# Full system status
/usr/local/bin/json2excel-status.sh

# Detailed health check
/usr/local/bin/json2excel-healthcheck.sh
```

### Container Diagnostics
```bash
# All containers
docker ps -a

# Specific container
docker inspect json2excel-app

# Container logs
docker logs json2excel-app --tail 100 -f

# Resource usage
docker stats json2excel-app --no-stream
```

### Network Diagnostics
```bash
# Port listening
ss -tlnp | grep -E ':(22|80|443|3000|6379)'

# Container network
docker network inspect json2excel-deployment_default

# DNS resolution
nslookup json2excel.devtestenv.org

# Connection test
curl -I http://localhost/
curl -I https://localhost/
```

### System Diagnostics
```bash
# Disk space
df -h

# Memory
free -h

# CPU
top -bn1 | head -20

# Processes
ps aux | grep -E '(docker|nginx|node)'

# SELinux
getenforce
sestatus

# Firewall
firewall-cmd --list-all
```

---

## 📞 Emergency Contacts

### Kritik Durumlarda

**1. Container Tamamen Down:**
```bash
cd /opt/json2excel
docker compose down
docker compose up -d
```

**2. Sistem Reboot:**
```bash
systemctl reboot
# Containerlar otomatik başlar (unless-stopped policy)
```

**3. Full Restore (Backup'tan):**
```bash
cd /opt/json2excel
docker compose down

# Son backup'ı bul
ls -lt backups/app/*.tar.gz | head -1

# Restore
tar -xzf backups/app/app-YYYYMMDD-HHMMSS.tar.gz
tar -xzf backups/config/config-YYYYMMDD-HHMMSS.tar.gz

# Rebuild
docker compose up -d --build
```

---

## 📚 Daha Fazla Yardım

- **Deployment Guide:** `03-docs/DEPLOYMENT-COMPLETE-REPORT.md`
- **Management Guide:** `03-docs/MANAGEMENT-GUIDE.md`
- **Logs:** `/var/log/json2excel-*.log`
- **Docker Logs:** `docker compose logs`
