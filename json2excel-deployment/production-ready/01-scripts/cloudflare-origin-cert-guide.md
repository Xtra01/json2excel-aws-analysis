# Cloudflare Origin Certificate Kurulum Rehberi

## Sorun Analizi
- Let's Encrypt, Cloudflare proxy üzerinden doğrulama yapamıyor (523 hatası)
- Cloudflare proxy AÇIK olduğu için doğrudan sunucuya HTTP erişim yok
- DNS challenge için Cloudflare API key çalışmıyor

## ✅ ÇÖZÜM: Cloudflare Origin Certificate

### Adım 1: Cloudflare Dashboard'dan Sertifika Oluştur

1. **Cloudflare Dashboard'a Git:**
   ```
   https://dash.cloudflare.com/2c596d737d8b39d20df20b66f94197e9/devtestenv.org/ssl-tls/origin
   ```

2. **Create Certificate Butonuna Tıkla**

3. **Ayarları Yapılandır:**
   - Generate private key and CSR with Cloudflare
   - Hostnames: `json2excel.devtestenv.org` veya `*.devtestenv.org`
   - Certificate Validity: 15 years
   - Signature Algorithm: RSA (2048)

4. **Sertifikaları Kaydet:**
   - Origin Certificate (`.pem` uzantılı)
   - Private Key (`.key` uzantılı)

### Adım 2: Sertifikaları Sunucuya Yükle

**PowerShell'den çalıştır:**

```powershell
# 1. Cloudflare dashboard'dan aldığın sertifikaları kaydet
# origin-cert.pem ve private-key.key dosyalarını oluştur

# 2. Sunucuya yükle
scp origin-cert.pem root@31.56.214.200:/opt/json2excel/config/ssl/
scp private-key.key root@31.56.214.200:/opt/json2excel/config/ssl/
```

### Adım 3: Nginx Config Güncelle

```bash
ssh root@31.56.214.200
cd /opt/json2excel

# SSL dizini oluştur
mkdir -p config/ssl
chmod 600 config/ssl/private-key.key
chmod 644 config/ssl/origin-cert.pem

# Nginx config'i güncelle
cat > config/nginx.conf << 'EOF'
upstream app {
    server app:3000;
}

server {
    listen 80;
    server_name json2excel.devtestenv.org;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name json2excel.devtestenv.org;

    # Cloudflare Origin Certificate
    ssl_certificate /etc/nginx/ssl/origin-cert.pem;
    ssl_certificate_key /etc/nginx/ssl/private-key.key;

    # SSL Security
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Logs
    access_log /dev/stdout;
    error_log /dev/stderr;

    client_max_body_size 100M;

    location / {
        proxy_pass http://app;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    location /uploads {
        alias /var/lib/json2excel/uploads;
        expires 1d;
        add_header Cache-Control "public, immutable";
    }
}
EOF
```

### Adım 4: Docker Compose Volume Ekle

```bash
# docker-compose.yml nginx servisine volume ekle
cd /opt/json2excel
```

docker-compose.yml içinde nginx servisine ekle:
```yaml
  nginx:
    image: nginx:alpine
    container_name: json2excel-nginx
    volumes:
      - ./config/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./config/ssl:/etc/nginx/ssl:ro  # <-- BU SATIRI EKLE
      - /var/lib/json2excel/uploads:/var/lib/json2excel/uploads:ro
      - nginx-logs:/var/log/nginx
```

### Adım 5: Nginx Restart ve Test

```bash
# Container restart
docker compose restart nginx

# SSL test
curl -I https://json2excel.devtestenv.org

# Certificate kontrol
echo | openssl s_client -servername json2excel.devtestenv.org -connect 31.56.214.200:443 2>/dev/null | openssl x509 -noout -dates -issuer
```

### Adım 6: Cloudflare SSL Mode Ayarla

1. **SSL/TLS → Overview** sayfasına git:
   ```
   https://dash.cloudflare.com/2c596d737d8b39d20df20b66f94197e9/devtestenv.org/ssl-tls
   ```

2. **SSL Mode'u değiştir:**
   - ❌ Flexible (HTTP to Origin) - ESKİ
   - ✅ **Full (strict)** - YENİ (Cloudflare Origin Cert ile)

3. **Always Use HTTPS** aktif et:
   - SSL/TLS → Edge Certificates → Always Use HTTPS: ON

## Doğrulama Checklist

```bash
# ✅ 1. SSL sertifikası doğru yüklendi mi?
openssl x509 -in /opt/json2excel/config/ssl/origin-cert.pem -text -noout | grep "Issuer"

# ✅ 2. Nginx config geçerli mi?
docker exec json2excel-nginx nginx -t

# ✅ 3. HTTPS çalışıyor mu?
curl -I https://json2excel.devtestenv.org

# ✅ 4. HTTP → HTTPS redirect çalışıyor mu?
curl -I http://json2excel.devtestenv.org

# ✅ 5. Cloudflare Full SSL aktif mi?
curl -I https://json2excel.devtestenv.org | grep "cf-cache-status"
```

## Beklenen Sonuç

```
✅ HTTP 301 → HTTPS redirect
✅ HTTPS 200 OK
✅ Issuer: Cloudflare
✅ Valid: 15 years
✅ cf-cache-status: DYNAMIC/HIT
✅ Server: cloudflare
```

## Alternatif: Let's Encrypt DNS Challenge

Eğer Cloudflare API çalışırsa:

```bash
dnf install -y python3-certbot-dns-cloudflare

cat > /root/.secrets/cloudflare.ini << EOF
dns_cloudflare_email = admin@devtestenv.org
dns_cloudflare_api_key = YOUR_WORKING_API_KEY
EOF

chmod 600 /root/.secrets/cloudflare.ini

certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials /root/.secrets/cloudflare.ini \
  -d json2excel.devtestenv.org \
  --non-interactive \
  --agree-tos \
  --email admin@devtestenv.org
```

## Sorun Giderme

### 523 Origin Unreachable
- Nginx container çalışıyor mu? `docker ps`
- Port 443 açık mı? `netstat -tlnp | grep :443`
- Cloudflare SSL mode Full (strict) mi?

### Certificate Validation Failed
- Origin certificate Cloudflare'den mi alındı?
- Domain adı sertifikada var mı?
- Private key doğru mu?

### HTTP 502 Bad Gateway
- App container çalışıyor mu? `docker ps | grep app`
- Nginx upstream config doğru mu? `app:3000`
