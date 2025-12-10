# Cloudflare Origin Certificate Kurulum Scripti
# Bu script sertifika dosyalarını sunucuya yükler ve nginx yapılandırmasını günceller

param(
    [Parameter(Mandatory=$true)]
    [string]$CertPath,
    
    [Parameter(Mandatory=$true)]
    [string]$KeyPath,
    
    [string]$ServerIP = "31.56.214.200"
)

Write-Host "`n=== CLOUDFLARE ORIGIN SSL KURULUMU ===" -ForegroundColor Cyan
Write-Host "Sunucu: $ServerIP" -ForegroundColor White
Write-Host "Cert: $CertPath" -ForegroundColor White
Write-Host "Key: $KeyPath`n" -ForegroundColor White

# 1. Dosya kontrolü
if (-not (Test-Path $CertPath)) {
    Write-Host "❌ Certificate dosyası bulunamadı: $CertPath" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $KeyPath)) {
    Write-Host "❌ Private key dosyası bulunamadı: $KeyPath" -ForegroundColor Red
    exit 1
}

Write-Host "✅ SSL dosyaları bulundu" -ForegroundColor Green

# 2. SSL dizini oluştur
Write-Host "`n📁 Sunucuda SSL dizini oluşturuluyor..." -ForegroundColor Cyan
ssh root@$ServerIP "mkdir -p /opt/json2excel/config/ssl"

# 3. Sertifika dosyalarını yükle
Write-Host "📤 Certificate yükleniyor..." -ForegroundColor Cyan
scp $CertPath "root@${ServerIP}:/opt/json2excel/config/ssl/origin-cert.pem"

Write-Host "📤 Private key yükleniyor..." -ForegroundColor Cyan
scp $KeyPath "root@${ServerIP}:/opt/json2excel/config/ssl/private-key.key"

Write-Host "✅ SSL dosyaları yüklendi" -ForegroundColor Green

# 4. İzinleri ayarla
Write-Host "`n🔒 Dosya izinleri ayarlanıyor..." -ForegroundColor Cyan
ssh root@$ServerIP @"
chmod 600 /opt/json2excel/config/ssl/private-key.key
chmod 644 /opt/json2excel/config/ssl/origin-cert.pem
ls -la /opt/json2excel/config/ssl/
"@

# 5. Nginx config güncelle
Write-Host "`n⚙️ Nginx config güncelleniyor..." -ForegroundColor Cyan
ssh root@$ServerIP @"
cd /opt/json2excel
cp config/nginx.conf config/nginx.conf.backup-`$(date +%Y%m%d-%H%M%S)

cat > config/nginx.conf << 'EOF'
upstream app {
    server app:3000;
}

server {
    listen 80;
    server_name json2excel.devtestenv.org;
    return 301 https://\`$server_name\`$request_uri;
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
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security Headers
    add_header Strict-Transport-Security \"max-age=31536000; includeSubDomains\" always;
    add_header X-Frame-Options \"SAMEORIGIN\" always;
    add_header X-Content-Type-Options \"nosniff\" always;
    add_header X-XSS-Protection \"1; mode=block\" always;
    add_header Referrer-Policy \"strict-origin-when-cross-origin\" always;

    # Logs
    access_log /dev/stdout;
    error_log /dev/stderr;

    client_max_body_size 100M;
    client_body_timeout 120s;

    location / {
        proxy_pass http://app;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \`$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \`$host;
        proxy_set_header X-Real-IP \`$remote_addr;
        proxy_set_header X-Forwarded-For \`$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \`$scheme;
        proxy_cache_bypass \`$http_upgrade;
        proxy_read_timeout 120s;
        proxy_connect_timeout 120s;
    }

    location /uploads {
        alias /var/lib/json2excel/uploads;
        expires 1d;
        add_header Cache-Control \"public, immutable\";
    }
}
EOF

echo '✅ Nginx config güncellendi'
"@

# 6. Docker Compose volume ekle
Write-Host "`n🐳 Docker Compose güncelleniyor..." -ForegroundColor Cyan
ssh root@$ServerIP @"
cd /opt/json2excel

# docker-compose.yml backup
cp docker-compose.yml docker-compose.yml.backup-`$(date +%Y%m%d-%H%M%S)

# SSL volume var mı kontrol et
if ! grep -q 'config/ssl' docker-compose.yml; then
    # nginx volumes bölümüne SSL mount ekle
    sed -i '/nginx:/,/^  [a-z]/ {
        /volumes:/a\      - ./config/ssl:/etc/nginx/ssl:ro
    }' docker-compose.yml
    echo '✅ docker-compose.yml güncellendi (SSL volume eklendi)'
else
    echo 'ℹ️  SSL volume zaten mevcut'
fi
"@

# 7. Nginx restart
Write-Host "`n🔄 Nginx container yeniden başlatılıyor..." -ForegroundColor Cyan
ssh root@$ServerIP @"
cd /opt/json2excel
docker compose restart nginx
sleep 5
docker ps --filter 'name=nginx' --format 'table {{.Names}}\t{{.Status}}'
"@

# 8. Testler
Write-Host "`n🧪 SSL TESTLER" -ForegroundColor Cyan

Write-Host "`n1️⃣ Nginx config testi:" -ForegroundColor Yellow
ssh root@$ServerIP "docker exec json2excel-nginx nginx -t"

Write-Host "`n2️⃣ HTTP → HTTPS redirect:" -ForegroundColor Yellow
$httpStatus = ssh root@$ServerIP "curl -s -o /dev/null -w '%{http_code}' http://localhost/"
if ($httpStatus -eq "301") {
    Write-Host "✅ HTTP 301 Redirect OK" -ForegroundColor Green
} else {
    Write-Host "❌ Redirect FAILED: HTTP $httpStatus" -ForegroundColor Red
}

Write-Host "`n3️⃣ HTTPS test:" -ForegroundColor Yellow
$httpsStatus = ssh root@$ServerIP "curl -k -s -o /dev/null -w '%{http_code}' https://localhost/"
if ($httpsStatus -eq "200") {
    Write-Host "✅ HTTPS 200 OK" -ForegroundColor Green
} else {
    Write-Host "❌ HTTPS FAILED: $httpsStatus" -ForegroundColor Red
}

Write-Host "`n4️⃣ SSL certificate kontrol:" -ForegroundColor Yellow
ssh root@$ServerIP "echo | openssl s_client -servername json2excel.devtestenv.org -connect localhost:443 2>/dev/null | openssl x509 -noout -dates -issuer"

Write-Host "`n5️⃣ External HTTPS test:" -ForegroundColor Yellow
$externalStatus = curl -s -o $null -w '%{http_code}' https://json2excel.devtestenv.org
if ($externalStatus -eq "200") {
    Write-Host "✅ External HTTPS 200 OK" -ForegroundColor Green
} else {
    Write-Host "⚠️  External HTTPS: $externalStatus (Cloudflare SSL mode kontrol et)" -ForegroundColor Yellow
}

# 9. Final sonuç
Write-Host "`n=== KURULUM TAMAMLANDI ===" -ForegroundColor Green
Write-Host @"

📋 Sonraki Adımlar:

1. Cloudflare Dashboard → SSL/TLS → Overview
   URL: https://dash.cloudflare.com/2c596d737d8b39d20df20b66f94197e9/devtestenv.org/ssl-tls
   
2. SSL Mode'u değiştir:
   ❌ Flexible → ✅ Full (strict)
   
3. Always Use HTTPS aktif et:
   SSL/TLS → Edge Certificates → Always Use HTTPS: ON

4. Test:
   curl -I https://json2excel.devtestenv.org

"@ -ForegroundColor Cyan

Write-Host "🎉 SSL kurulumu başarıyla tamamlandı!`n" -ForegroundColor Green
