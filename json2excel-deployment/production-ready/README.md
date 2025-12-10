# JSON to Excel - Production Deployment Package

**Status:** ✅ PRODUCTION READY  
**Version:** 1.0.0  
**Last Update:** 10 Aralık 2025

---

## 📋 İÇİNDEKİLER

- [Genel Bakış](#genel-bakış)
- [Hızlı Başlangıç](#hızlı-başlangıç)
- [Klasör Yapısı](#klasör-yapısı)
- [Sistem Gereksinimleri](#sistem-gereksinimleri)
- [Kurulum Adımları](#kurulum-adımları)
- [Yönetim](#yönetim)
- [Sorun Giderme](#sorun-giderme)
- [Destek](#destek)

---

## 🎯 GENEL BAKIŞ

### Proje Bilgileri

Bu paket, **JSON to Excel Converter** uygulamasının production ortamına deploy edilmesi için gerekli tüm dosya ve dokümantasyonu içerir.

**Uygulama Özellikleri:**
- Next.js 14.2.15 (React, TypeScript)
- Docker Compose orchestration
- Nginx reverse proxy
- Redis cache
- Otomatik backup ve monitoring

**Sunucu Özellikleri:**
- AlmaLinux 8.10
- Podman 4.9.4-rhel (Docker compat)
- 32GB RAM, 4 vCore, 120GB SSD
- Cloudflare CDN + SSL Proxy

### Deployment Durumu

✅ **Tamamlandı:**
- Source code deployment
- Docker build ve container orchestration
- HTTP → HTTPS redirect
- Security hardening (Firewall, Fail2ban, SSH)
- Security headers (HSTS, CSP, X-Frame-Options)
- Rate limiting (API: 10/s, General: 50/s)
- Otomatik backup (günlük 03:00, 7 gün rotasyon)
- Health monitoring (5 dakika interval)
- Container restart policies

⏳ **Opsiyonel:**
- Cloudflare Origin Certificate (manuel kurulum)

### Performans Metrikleri

- **Response Time:** 35-40ms (average)
- **Uptime:** 99.9% hedef
- **Resource Usage:** CPU 1-2%, Memory 2%, Disk 16%
- **Auto-recovery:** Enabled (unless-stopped policy)

---

## 🚀 HIZLI BAŞLANGIÇ

### 1. Minimum Kurulum (15 dakika)

```powershell
# 1. Repository clone
git clone <repo-url>
cd json2excel-deployment/production-ready

# 2. Environment setup
cp 02-configs/.env.example ../.env.production
# Düzenle: SERVER_IP, SSH_KEY_PATH

# 3. SSH key kurulum
ssh-copy-id -i ~/.ssh/your_key.pub root@SERVER_IP

# 4. Deployment
python 01-scripts/deploy-production.py
```

### 2. Tam Kurulum (30 dakika)

Yukarıdaki adımlara ek olarak:

```bash
# SSH ile sunucuya bağlan
ssh root@SERVER_IP

# Güvenlik kurulumu
bash /tmp/setup-backup-system.sh
bash /tmp/setup-monitoring.sh

# Fail2ban
dnf install -y fail2ban fail2ban-firewalld
systemctl enable --now fail2ban
```

### 3. SSL Certificate (Manuel - 10 dakika)

```
1. Cloudflare Dashboard → SSL/TLS → Origin Server
2. Create Certificate → json2excel.devtestenv.org
3. Download: origin-cert.pem, private-key.key
4. Run: .\01-scripts\setup-cloudflare-ssl.ps1
5. Cloudflare SSL Mode: Flexible → Full (strict)
```

### 4. Doğrulama

```bash
# Status check
ssh root@SERVER_IP "/usr/local/bin/json2excel-status.sh"

# Web test
curl -I https://json2excel.devtestenv.org
```

---

## 📁 KLASÖR YAPISI

```
production-ready/
│
├── 01-scripts/                          # Kurulum ve yönetim scriptleri
│   ├── deploy-production.py            # Ana deployment script
│   ├── setup-backup-system.sh          # Backup sistemi kurulumu
│   ├── setup-monitoring.sh             # Monitoring kurulumu
│   ├── setup-cloudflare-ssl.ps1        # SSL sertifika yükleyici
│   └── cloudflare-origin-cert-guide.md # SSL kurulum rehberi
│
├── 02-configs/                          # Yapılandırma dosyaları
│   ├── nginx.conf                       # Production nginx config
│   ├── docker-compose.yml               # Container orchestration
│   ├── Dockerfile                       # Multi-stage build
│   └── .env.example                     # Environment variables template
│
├── 03-docs/                             # Dokümantasyon
│   ├── DEPLOYMENT-COMPLETE-REPORT.md    # Tam deployment raporu
│   ├── DEPLOYMENT-SUMMARY.md            # Özet deployment bilgileri
│   ├── CLOUDFLARE-DNS-MANUAL.md         # DNS kurulum rehberi
│   ├── TROUBLESHOOTING.md               # Sorun giderme rehberi
│   ├── MANAGEMENT-GUIDE.md              # Yönetim kılavuzu
│   └── PRODUCTION-READY-REPORT.md       # Production hazırlık raporu
│
├── 04-backups/                          # Backup rehberleri
│   └── RESTORE-GUIDE.md                 # Restore işlemleri rehberi
│
├── DEPLOYMENT-COMPLETE-REPORT.md        # Ana rapor (bu klasörde de)
└── README.md                            # Bu dosya
```

### Dosya Açıklamaları

**Scripts:**
- `deploy-production.py`: Python deployment script (paramiko kullanır)
- `setup-backup-system.sh`: Otomatik backup sistemi kurulumu
- `setup-monitoring.sh`: Health check ve monitoring kurulumu
- `setup-cloudflare-ssl.ps1`: PowerShell SSL certificate installer

**Configs:**
- `nginx.conf`: Security headers, rate limiting, SSL config
- `docker-compose.yml`: 4 container orchestration (app, nginx, redis, logrotate)
- `Dockerfile`: Multi-stage Next.js build
- `.env.example`: Sunucu bilgileri template

**Docs:**
- `DEPLOYMENT-COMPLETE-REPORT.md`: 13,000+ kelime tam rapor
- `TROUBLESHOOTING.md`: 12 yaygın sorun + çözümleri
- `MANAGEMENT-GUIDE.md`: Günlük/haftalık/aylık yönetim görevleri
- `RESTORE-GUIDE.md`: 6 farklı restore senaryosu

---

## 💻 SİSTEM GEREKSİNİMLERİ

### Sunucu (Minimum)

- **OS:** AlmaLinux 8+ / RHEL 8+ / CentOS 8+
- **CPU:** 2 vCore
- **RAM:** 4GB
- **Disk:** 20GB SSD
- **Network:** 100 Mbps

### Sunucu (Önerilen - Production)

- **OS:** AlmaLinux 8.10+
- **CPU:** 4+ vCore
- **RAM:** 8GB+
- **Disk:** 40GB+ SSD
- **Network:** 1 Gbps

### Yerel Makine

- **OS:** Windows 10+ (PowerShell) veya Linux/macOS
- **SSH Client:** OpenSSH
- **Python:** 3.6+ (paramiko library)
- **Git:** 2.0+

### Network Gereksinimleri

- Sunucuya SSH erişimi (port 22)
- HTTP/HTTPS portları (80, 443) açık
- DNS yapılandırması (Cloudflare)
- İnternet erişimi (package download için)

---

## 📖 KURULUM ADIMLARI

### Adım 1: Hazırlık (5 dakika)

**1.1. Repository'yi kopyala:**
```powershell
git clone <repo-url>
cd json2excel-deployment/production-ready
```

**1.2. Environment dosyasını ayarla:**
```powershell
cp 02-configs/.env.example ../.env.production
notepad ..\.env.production
```

Düzenle:
```env
SERVER_IP=31.56.214.200
SERVER_USER=root
SERVER_PASSWORD=your_password
SSH_KEY_PATH=~/.ssh/json2excel_deploy

CLOUDFLARE_ZONE_ID=your_zone_id
CLOUDFLARE_API_KEY=your_api_key
CLOUDFLARE_EMAIL=your_email

DOMAIN=json2excel.devtestenv.org
```

**1.3. SSH key oluştur:**
```powershell
ssh-keygen -t ed25519 -f ~/.ssh/json2excel_deploy -C "json2excel-deploy"
```

### Adım 2: SSH Kurulumu (2 dakika)

```powershell
# Public key'i sunucuya kopyala
$pubKey = Get-Content ~/.ssh/json2excel_deploy.pub
ssh root@31.56.214.200 "mkdir -p ~/.ssh && echo '$pubKey' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

# Test
ssh -i ~/.ssh/json2excel_deploy root@31.56.214.200 "echo 'SSH key çalışıyor!'"
```

### Adım 3: Ana Deployment (10-15 dakika)

```powershell
# Python dependencies
pip install paramiko

# Deploy
cd production-ready/01-scripts
python deploy-production.py
```

**Script otomatik olarak:**
1. Source code transfer (~500MB)
2. SELinux context ayarlama
3. Docker build (10-15 dakika)
4. Container başlatma
5. Health check

### Adım 4: Güvenlik Yapılandırması (5 dakika)

```bash
# SSH ile sunucuya bağlan
ssh root@31.56.214.200

# Backup sistemi
bash /tmp/setup-backup-system.sh

# Monitoring
bash /tmp/setup-monitoring.sh

# Fail2ban
dnf install -y fail2ban fail2ban-firewalld
systemctl enable --now fail2ban

# SSH hardening
sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^PermitRootLogin yes/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
systemctl restart sshd
```

### Adım 5: SSL Certificate (10 dakika - Opsiyonel)

**5.1. Cloudflare Dashboard:**
```
URL: https://dash.cloudflare.com/YOUR_ACCOUNT_ID/YOUR_DOMAIN/ssl-tls/origin
```

**5.2. Create Certificate:**
- Hostname: `json2excel.devtestenv.org` veya `*.devtestenv.org`
- Validity: 15 years
- Key Type: RSA (2048)

**5.3. Download:**
- `origin-cert.pem` (Certificate)
- `private-key.key` (Private Key)

**5.4. Upload:**
```powershell
cd production-ready/01-scripts
.\setup-cloudflare-ssl.ps1 -CertPath .\origin-cert.pem -KeyPath .\private-key.key
```

**5.5. Cloudflare SSL Mode:**
- Dashboard → SSL/TLS → Overview
- SSL Mode: **Flexible** → **Full (strict)**
- Always Use HTTPS: **ON**

### Adım 6: DNS Yapılandırması (5 dakika)

**6.1. Cloudflare Dashboard:**
```
URL: https://dash.cloudflare.com/YOUR_ACCOUNT_ID/YOUR_DOMAIN/dns/records
```

**6.2. A Record Ekle:**
- Type: **A**
- Name: **json2excel**
- Content: **31.56.214.200**
- Proxy: **ON** (turuncu bulut)
- TTL: Auto

**6.3. Test:**
```powershell
nslookup json2excel.devtestenv.org
curl -I https://json2excel.devtestenv.org
```

### Adım 7: Final Verification (2 dakika)

```bash
# SSH bağlantısı
ssh root@31.56.214.200

# Full status check
/usr/local/bin/json2excel-status.sh

# Health check
/usr/local/bin/json2excel-healthcheck.sh

# Web test
curl -I http://localhost/        # 301 bekleniyor
curl -I https://localhost/       # 200 bekleniyor
```

**Beklenen çıktı:**
```
✅ 4/4 Container running
✅ HTTP: 301, HTTPS: 200
✅ Response time: <50ms
✅ Disk: <20%, Memory: <10%
✅ Backup: Configured
```

---

## 🔧 YÖNETİM

### Günlük İşlemler

```bash
# Status kontrolü
/usr/local/bin/json2excel-status.sh

# Logs
docker compose -f /opt/json2excel/docker-compose.yml logs -f

# Container restart
docker compose -f /opt/json2excel/docker-compose.yml restart
```

### Container Yönetimi

```bash
# Tüm containerlar
docker ps

# Specific container
docker logs json2excel-app
docker restart json2excel-nginx

# Resource monitoring
docker stats --no-stream
```

### Backup ve Restore

```bash
# Manuel backup
/usr/local/bin/json2excel-backup.sh

# Backup listesi
ls -lh /opt/json2excel/backups/*/*

# Restore (detaylı rehber: 04-backups/RESTORE-GUIDE.md)
cd /opt/json2excel
tar -xzf backups/app/app-YYYYMMDD-HHMMSS.tar.gz
docker compose up -d --build
```

### Monitoring

```bash
# Health check
/usr/local/bin/json2excel-healthcheck.sh

# Logs
tail -f /var/log/json2excel-health.log
tail -f /var/log/json2excel-backup.log

# Resource usage
df -h
free -h
docker stats
```

**Detaylı yönetim bilgileri:** `03-docs/MANAGEMENT-GUIDE.md`

---

## 🚨 SORUN GİDERME

### Yaygın Sorunlar

**1. Container çalışmıyor:**
```bash
docker ps
docker logs json2excel-app --tail 100
docker compose restart
```

**2. HTTPS 523 error:**
```bash
docker ps | grep nginx
docker logs json2excel-nginx
docker compose restart nginx
```

**3. Build hatası:**
```bash
chcon -Rt svirt_sandbox_file_t /opt/json2excel/app
docker compose build --no-cache
```

**4. SSH connection refused:**
```bash
# Sunucu panelinden:
systemctl status sshd
firewall-cmd --add-service=ssh --permanent
```

**5. Disk dolu:**
```bash
docker system prune -a --volumes
find /opt/json2excel/backups -mtime +7 -delete
```

**Detaylı sorun giderme:** `03-docs/TROUBLESHOOTING.md`

---

## 📚 DOKÜMANTASYON

### Ana Dokümantasyon

1. **DEPLOYMENT-COMPLETE-REPORT.md** (13,000+ kelime)
   - Tam deployment raporu
   - Çözülen problemler (8 major issue)
   - Sistem gereksinimleri
   - Yeniden kurulum adımları

2. **MANAGEMENT-GUIDE.md** (8,000+ kelime)
   - Günlük/haftalık/aylık görevler
   - Container yönetimi
   - Performance tuning
   - Emergency procedures

3. **TROUBLESHOOTING.md** (5,000+ kelime)
   - 12 yaygın sorun + çözümleri
   - Diagnostic commands
   - Emergency recovery

4. **RESTORE-GUIDE.md** (4,000+ kelime)
   - 6 farklı restore senaryosu
   - Backup verification
   - Recovery procedures

### Hızlı Referans

**Kurulum:**
- `01-scripts/cloudflare-origin-cert-guide.md`
- `03-docs/CLOUDFLARE-DNS-MANUAL.md`

**Yönetim:**
- `03-docs/MANAGEMENT-GUIDE.md`

**Sorun Giderme:**
- `03-docs/TROUBLESHOOTING.md`

**Backup/Restore:**
- `04-backups/RESTORE-GUIDE.md`

---

## 🎯 ÖZELLİKLER

### Güvenlik

✅ **Firewall:** firewalld (80, 443, 22)  
✅ **Fail2ban:** SSH brute force koruması (5 deneme, 1 saat ban)  
✅ **SSH Hardening:** Key-only authentication, password disabled  
✅ **SELinux:** Enforcing mode  
✅ **Security Headers:** HSTS, CSP, X-Frame-Options, X-Content-Type-Options  
✅ **Rate Limiting:** API 10/s, General 50/s  

### Operations

✅ **Auto Backup:** Günlük 03:00, 7 gün rotasyon  
✅ **Health Monitoring:** 5 dakika interval, otomatik kontrol  
✅ **Log Rotation:** Otomatik (logrotate container)  
✅ **Auto Restart:** Container crash'de otomatik restart  

### Performance

✅ **CDN:** Cloudflare global network  
✅ **Caching:** Redis + Nginx static cache  
✅ **SSL:** Cloudflare SSL proxy  
✅ **Response Time:** 35-40ms average  

---

## 📞 DESTEK

### Sunucu Bilgileri

- **IP:** 31.56.214.200
- **Domain:** https://json2excel.devtestenv.org
- **SSH:** `ssh root@31.56.214.200` (key-only)
- **Panel:** verisunucu.net

### Erişim URL'leri

- **Web:** https://json2excel.devtestenv.org
- **API:** https://json2excel.devtestenv.org/api/convert
- **Health:** https://json2excel.devtestenv.org/api/health

### Log Dosyaları

- **Application:** `docker logs json2excel-app`
- **Nginx:** `docker logs json2excel-nginx`
- **Health:** `/var/log/json2excel-health.log`
- **Backup:** `/var/log/json2excel-backup.log`
- **Fail2ban:** `/var/log/fail2ban.log`

### Yönetim Komutları

```bash
# Status
/usr/local/bin/json2excel-status.sh

# Health check
/usr/local/bin/json2excel-healthcheck.sh

# Backup
/usr/local/bin/json2excel-backup.sh
```

---

## ✅ CHECKLIST

### Deployment Checklist

- [x] Source code transferred
- [x] Docker build successful
- [x] All containers running (4/4)
- [x] HTTP → HTTPS redirect (301)
- [x] Application accessible (200 OK)
- [x] DNS configured (Cloudflare)
- [ ] **SSL certificate** (Cloudflare Origin - opsiyonel)

### Security Checklist

- [x] Firewall configured (80, 443, 22)
- [x] Fail2ban active (4 IPs banned)
- [x] SSH hardening (key-only)
- [x] SELinux enforcing
- [x] Security headers (full set)
- [x] Rate limiting (API + General)

### Operations Checklist

- [x] Backup system (daily 03:00)
- [x] Health monitoring (5 min)
- [x] Container restart policies
- [x] Log rotation
- [x] Status scripts

### Documentation Checklist

- [x] Deployment guide (13,000+ words)
- [x] Management guide (8,000+ words)
- [x] Troubleshooting guide (5,000+ words)
- [x] Restore procedures (4,000+ words)
- [x] Quick reference (this file)

---

## 📊 PERFORMANS

### Mevcut Metrikler

**Response Times:**
- HTTP: <5ms
- HTTPS: 35-40ms
- API: 40-50ms

**Resource Usage:**
- CPU: 1-2% (idle)
- Memory: 625Mi / 31Gi (2%)
- Disk: 18G / 118G (16%)

**Availability:**
- Uptime: 100% (son 24 saat)
- Health Check: ✅ Passing
- Auto-recovery: Enabled

---

## 🎓 NOTLAR

### Yapılan Optimizasyonlar

1. ✅ Multi-stage Docker build
2. ✅ Next.js standalone output
3. ✅ Nginx static caching
4. ✅ Redis session caching
5. ✅ Log rotation
6. ✅ SELinux optimization
7. ✅ Container restart policies
8. ✅ Health monitoring

### Bilinen Sınırlamalar

1. ⚠️ Let's Encrypt HTTP challenge Cloudflare proxy ile çalışmaz → Çözüm: Origin Certificate
2. ⚠️ Podman docker-compose uyumluluğu sınırlı → Çözüm: Standalone binary
3. ⚠️ SELinux context sorunları → Çözüm: `chcon -Rt svirt_sandbox_file_t`
4. ⚠️ Cloudflare API key hatası → Çözüm: Manuel dashboard

### Öğrenilen Dersler

**Technical:**
- Cloudflare proxy + Let's Encrypt HTTP challenge çalışmaz
- Podman SELinux context kritik
- Container logging stdout/stderr kullanmalı
- TypeScript build'e broken files dahil etme

**Operational:**
- Live monitoring uzun build'lerde şart
- Her adımı dokümante et
- Günlük backup + test restore
- 5 dakika health check yeterli

---

## 📄 LİSANS

Bu deployment package'ı JSON to Excel projesinin bir parçasıdır.

---

**Version:** 1.0.0  
**Last Update:** 10 Aralık 2025  
**Status:** ✅ PRODUCTION READY
