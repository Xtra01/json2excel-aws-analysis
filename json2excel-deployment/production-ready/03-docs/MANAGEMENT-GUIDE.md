# Yönetim Rehberi

## 🎯 Günlük Operasyonlar

### 1. System Status Kontrolü

**Her sabah yapılması önerilen:**

```bash
# SSH bağlantısı
ssh root@31.56.214.200

# Hızlı status
/usr/local/bin/json2excel-status.sh
```

**Beklenen çıktı:**
```
✅ 4/4 Container running
✅ HTTP 301, HTTPS 200
✅ CPU: 1-2%, Memory: 2%, Disk: 16%
✅ Backup: Son 24 saatte başarılı
```

### 2. Log Kontrolü

```bash
# Health check logs (son 1 saat)
tail -100 /var/log/json2excel-health.log | grep "$(date +%Y-%m-%d)"

# Backup logs
tail -50 /var/log/json2excel-backup.log

# Application errors
docker compose logs --since 24h | grep -i error
```

### 3. Resource Monitoring

```bash
# Container resources
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Disk space
df -h / | grep -v tmp

# Memory
free -h | grep Mem
```

---

## 🔧 Haftalık Bakım

### 1. Backup Verification (Her Pazartesi)

```bash
# Son 7 günün backupları var mı?
find /opt/json2excel/backups -name "*.tar.gz" -mtime -7 | wc -l
# Beklenen: 28+ dosya (4 tip × 7 gün)

# Backup boyutları normal mi?
du -sh /opt/json2excel/backups/*/
# app: ~50MB, config: ~10KB, redis: varies, uploads: varies

# Backup integrity test
tar -tzf $(ls -t /opt/json2excel/backups/app/app-*.tar.gz | head -1) > /dev/null
echo "Backup test: $?"  # 0 = başarılı
```

### 2. Security Audit

```bash
# Fail2ban banned IPs
fail2ban-client status sshd | grep "Currently banned"

# Firewall rules
firewall-cmd --list-all

# SSH config
grep -E "^(PermitRootLogin|PasswordAuthentication)" /etc/ssh/sshd_config
# Beklenen:
# PermitRootLogin prohibit-password
# PasswordAuthentication no

# SSL certificate expiry
openssl x509 -in /opt/json2excel/config/ssl/origin-cert.pem -noout -dates
```

### 3. Performance Review

```bash
# Response time testi
for i in {1..10}; do
  curl -w "Time: %{time_total}s\n" -o /dev/null -s https://json2excel.devtestenv.org
done | awk '{sum+=$2; count++} END {print "Average:", sum/count "s"}'
# Beklenen: <0.1s

# Container uptime
docker ps --format "table {{.Names}}\t{{.Status}}"

# Error rate (son 24 saat)
docker compose logs --since 24h | grep -c -i error
# Beklenen: <10
```

---

## 📅 Aylık Görevler

### 1. Full System Backup (Ayın 1'i)

```bash
# Off-site backup
tar -czf /tmp/json2excel-full-$(date +%Y%m).tar.gz \
  /opt/json2excel/backups/ \
  /opt/json2excel/config/ \
  /var/log/json2excel-*.log

# Uzak sunucuya kopyala
scp /tmp/json2excel-full-*.tar.gz backup-server:/backups/
```

### 2. System Update (Ayın 15'i)

```bash
# Package updates (dikkatli!)
dnf check-update
dnf update -y --exclude=kernel*

# Docker cleanup
docker system prune -a --volumes

# Restart (gerekirse)
systemctl reboot
```

### 3. Capacity Planning

```bash
# Disk usage trend
df -h / | tee -a /var/log/capacity-$(date +%Y%m).log

# Container resource trend
docker stats --no-stream >> /var/log/container-stats-$(date +%Y%m).log

# Backup size trend
du -sh /opt/json2excel/backups/ | tee -a /var/log/backup-size-$(date +%Y%m).log
```

---

## 🚀 Deployment Operasyonları

### 1. Application Update

**Yeni versiyon deploy etme:**

```bash
# 1. Backup al
/usr/local/bin/json2excel-backup.sh

# 2. Yeni kodu transfer et
# Yerel makineden:
rsync -avz --exclude='node_modules' --exclude='.next' \
  /path/to/app/ root@31.56.214.200:/opt/json2excel/app/

# 3. Sunucuda build
ssh root@31.56.214.200
cd /opt/json2excel
docker compose down
docker compose up -d --build

# 4. Health check
sleep 30
/usr/local/bin/json2excel-healthcheck.sh

# 5. Test
curl -I https://json2excel.devtestenv.org
```

### 2. Config Update

**Nginx veya docker-compose güncellemesi:**

```bash
# 1. Backup
cp /opt/json2excel/config/nginx.conf \
   /opt/json2excel/config/nginx.conf.backup-$(date +%Y%m%d)

# 2. Düzenle
vi /opt/json2excel/config/nginx.conf

# 3. Test
docker exec json2excel-nginx nginx -t

# 4. Apply
docker compose restart nginx

# 5. Verify
curl -I http://localhost/
curl -I https://localhost/
```

### 3. Rollback

**Sorunlu deployment geri alma:**

```bash
# 1. Stop mevcut
docker compose down

# 2. Son sağlıklı backup restore
cd /opt/json2excel
tar -xzf backups/app/app-LAST_GOOD_DATE.tar.gz
tar -xzf backups/config/config-LAST_GOOD_DATE.tar.gz

# 3. SELinux fix
chcon -Rt svirt_sandbox_file_t app/

# 4. Start
docker compose up -d

# 5. Verify
/usr/local/bin/json2excel-healthcheck.sh
```

---

## 🔐 Security Operations

### 1. Fail2ban Yönetimi

```bash
# Banned IP listesi
fail2ban-client status sshd

# IP unban
fail2ban-client set sshd unbanip <IP>

# Whitelist ekle
echo "ignoreip = 127.0.0.1/8 YOUR_TRUSTED_IP" \
  >> /etc/fail2ban/jail.d/sshd.local
systemctl restart fail2ban

# Ban history
grep "Ban " /var/log/fail2ban.log | tail -20
```

### 2. Firewall Yönetimi

```bash
# Port açma (geçici)
firewall-cmd --add-port=8080/tcp

# Port açma (kalıcı)
firewall-cmd --permanent --add-port=8080/tcp
firewall-cmd --reload

# Service açma
firewall-cmd --permanent --add-service=https
firewall-cmd --reload

# IP blocking
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="1.2.3.4" reject'
firewall-cmd --reload
```

### 3. SSL Certificate Renewal

**Cloudflare Origin Certificate (15 yıl geçerli):**

```bash
# Expiry check
openssl x509 -in /opt/json2excel/config/ssl/origin-cert.pem -noout -dates

# Yenileme gerekirse:
# 1. Cloudflare Dashboard → SSL/TLS → Origin Server
# 2. Create new certificate
# 3. Download: origin-cert.pem, private-key.key

# Yükle (local makineden)
scp origin-cert.pem root@31.56.214.200:/opt/json2excel/config/ssl/
scp private-key.key root@31.56.214.200:/opt/json2excel/config/ssl/

# Permissions
chmod 644 /opt/json2excel/config/ssl/origin-cert.pem
chmod 600 /opt/json2excel/config/ssl/private-key.key

# Nginx reload
docker compose restart nginx
```

---

## 📊 Monitoring ve Alerting

### 1. Custom Health Check

```bash
# Özel metrik topla
cat > /usr/local/bin/custom-metrics.sh << 'EOF'
#!/bin/bash
echo "$(date '+%Y-%m-%d %H:%M:%S')," \
     "$(docker ps | wc -l)," \
     "$(docker stats --no-stream --format '{{.CPUPerc}}' json2excel-app | tr -d '%')," \
     "$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')," \
     "$(curl -s -o /dev/null -w '%{time_total}' https://localhost/)" \
  >> /var/log/metrics.csv
EOF

chmod +x /usr/local/bin/custom-metrics.sh

# Crontab ekle (her 5 dakika)
echo "*/5 * * * * /usr/local/bin/custom-metrics.sh" | crontab -
```

### 2. Email Alerting (Opsiyonel)

```bash
# Postfix kur
dnf install -y postfix mailx

# SMTP config
vi /etc/postfix/main.cf
# relayhost = [smtp.gmail.com]:587
# smtp_use_tls = yes
# smtp_sasl_auth_enable = yes

systemctl enable --now postfix

# Test
echo "Test email" | mail -s "Test" admin@devtestenv.org
```

### 3. Slack/Discord Webhook (Opsiyonel)

```bash
# Health check'e webhook ekle
vi /usr/local/bin/json2excel-healthcheck.sh

# Alert fonksiyonunu güncelle:
alert() {
    local subject="$1"
    local message="$2"
    log "🚨 ALERT: $subject - $message"
    
    # Slack webhook
    curl -X POST https://hooks.slack.com/services/YOUR/WEBHOOK/URL \
      -H 'Content-Type: application/json' \
      -d "{\"text\":\"🚨 $subject: $message\"}"
}
```

---

## 🔄 Container Yönetimi

### 1. Individual Container Operations

```bash
# Start/Stop
docker compose start json2excel-app
docker compose stop json2excel-app

# Restart
docker compose restart json2excel-app

# Logs
docker logs -f json2excel-app

# Shell erişimi
docker exec -it json2excel-app sh

# Resource limits check
docker inspect json2excel-app --format='{{.HostConfig.Memory}}'
```

### 2. Bulk Operations

```bash
# Tüm containerları restart
docker compose restart

# Tüm containerları rebuild
docker compose down
docker compose up -d --build

# Cleanup
docker compose down --volumes --remove-orphans
docker system prune -a
```

### 3. Image Management

```bash
# Image listesi
docker images | grep json2excel

# Image boyutu
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep json2excel

# Eski image'ları temizle
docker images | grep "none" | awk '{print $3}' | xargs docker rmi
```

---

## 📈 Performance Tuning

### 1. Nginx Optimization

```bash
# Cache tuning
vi /opt/json2excel/config/nginx.conf

# Ekle:
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=app_cache:10m max_size=100m;

server {
    location / {
        proxy_cache app_cache;
        proxy_cache_valid 200 5m;
        ...
    }
}

# Apply
docker compose restart nginx
```

### 2. Redis Memory Optimization

```bash
# Redis config
docker exec json2excel-redis redis-cli CONFIG GET maxmemory
docker exec json2excel-redis redis-cli CONFIG SET maxmemory 256mb
docker exec json2excel-redis redis-cli CONFIG SET maxmemory-policy allkeys-lru
```

### 3. App Performance

```bash
# Node.js memory limit
vi /opt/json2excel/docker-compose.yml

services:
  app:
    environment:
      - NODE_OPTIONS=--max-old-space-size=2048

# Apply
docker compose up -d app
```

---

## 🗑️ Cleanup Operations

### 1. Log Rotation Manual

```bash
# Application logs
truncate -s 0 /var/log/json2excel-health.log
truncate -s 0 /var/log/json2excel-backup.log

# Docker logs
docker compose logs --tail 0 > /dev/null

# System logs
journalctl --vacuum-time=7d
```

### 2. Disk Space Recovery

```bash
# Docker cleanup
docker system prune -a --volumes

# Eski kernels
dnf remove $(dnf repoquery --installonly --latest-limit=-2 -q)

# Temp files
find /tmp -type f -mtime +7 -delete

# Old backups (>14 gün)
find /opt/json2excel/backups -type f -mtime +14 -delete
```

### 3. Database Maintenance

```bash
# Redis data temizle
docker exec json2excel-redis redis-cli FLUSHALL

# Redis compact
docker exec json2excel-redis redis-cli BGSAVE
```

---

## 📋 Checklist Templates

### Daily Checklist
- [ ] System status check (`json2excel-status.sh`)
- [ ] Error logs review (last 24h)
- [ ] Resource usage normal? (<80%)
- [ ] Backup completed? (check log)
- [ ] Response time <100ms?

### Weekly Checklist
- [ ] Backup integrity test
- [ ] Fail2ban review (banned IPs)
- [ ] SSL certificate expiry check
- [ ] Performance metrics review
- [ ] Security audit

### Monthly Checklist
- [ ] Full system backup (off-site)
- [ ] System updates (non-kernel)
- [ ] Capacity planning review
- [ ] Documentation update
- [ ] Disaster recovery test

---

## 🆘 Emergency Procedures

### 1. Site Down (5xx Errors)

```bash
# 1. Quick status
docker ps
docker compose logs --tail 50

# 2. Restart all
docker compose restart

# 3. Still down? Rebuild
docker compose down
docker compose up -d --build

# 4. Still down? Restore backup
# (See RESTORE-GUIDE.md)
```

### 2. High CPU (>80%)

```bash
# 1. Identify process
docker stats --no-stream

# 2. Restart heavy container
docker compose restart json2excel-app

# 3. Check for loops
docker logs json2excel-app --tail 100 | grep -i error
```

### 3. Disk Full (>90%)

```bash
# 1. Emergency cleanup
docker system prune -a --volumes

# 2. Remove old backups
find /opt/json2excel/backups -mtime +3 -delete

# 3. Clear logs
journalctl --vacuum-size=100M
```

---

## 📞 Contacts ve Resources

**Documentation:**
- Deployment: `DEPLOYMENT-COMPLETE-REPORT.md`
- Troubleshooting: `TROUBLESHOOTING.md`
- Backup/Restore: `RESTORE-GUIDE.md`

**Logs:**
- Health: `/var/log/json2excel-health.log`
- Backup: `/var/log/json2excel-backup.log`
- Fail2ban: `/var/log/fail2ban.log`

**Scripts:**
- Status: `/usr/local/bin/json2excel-status.sh`
- Health: `/usr/local/bin/json2excel-healthcheck.sh`
- Backup: `/usr/local/bin/json2excel-backup.sh`

**Service URLs:**
- Web: https://json2excel.devtestenv.org
- API: https://json2excel.devtestenv.org/api/convert
- Health: https://json2excel.devtestenv.org/api/health
