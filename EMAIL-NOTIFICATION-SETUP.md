# 📧 Fail2ban Email Bildirim Kurulum Rehberi

## 🎯 Seçenek 1: Gmail SMTP (ÖNERİLEN - EN KOLAY)

### Avantajlar:
- ✅ Tamamen ücretsiz
- ✅ 5 dakikada kurulum
- ✅ Günlük 500 email limit (fazlasıyla yeterli)
- ✅ Google'ın güvenilir altyapısı

### Adım 1: Gmail App Password Oluştur

1. **Google hesabına giriş yap:** https://myaccount.google.com/
2. **Security** sekmesine git
3. **2-Step Verification** aktif et (zorunlu)
4. **App passwords** oluştur:
   - https://myaccount.google.com/apppasswords
   - App seçimi: **Mail**
   - Device seçimi: **Linux Computer**
   - **Generate** butonuna tıkla
   - 🔑 **16 haneli şifreyi kopyala** (örn: `abcd efgh ijkl mnop`)

---

### Adım 2: Postfix SMTP Konfigürasyonu

```bash
# Sunucuya bağlan
ssh root@31.56.214.200

# Gmail SMTP ayarlarını yap
cat > /etc/postfix/sasl_passwd << EOF
[smtp.gmail.com]:587 your-email@gmail.com:abcdefghijklmnop
EOF

# Dosya izinlerini güvenli hale getir
chmod 600 /etc/postfix/sasl_passwd
postmap /etc/postfix/sasl_passwd

# Postfix main.cf düzenle
cat >> /etc/postfix/main.cf << EOF

# Gmail SMTP Settings
relayhost = [smtp.gmail.com]:587
smtp_use_tls = yes
smtp_sasl_auth_enable = yes
smtp_sasl_security_options = noanonymous
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_tls_CAfile = /etc/ssl/certs/ca-bundle.crt
EOF

# Postfix'i yeniden başlat
systemctl restart postfix
systemctl enable postfix

# Test email gönder
echo "Test email from fail2ban" | mail -s "Fail2ban Test" your-email@gmail.com
```

---

### Adım 3: Fail2ban Email Ayarları

```bash
# Fail2ban jail.local'i düzenle
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
# Email settings
destemail = your-email@gmail.com
sendername = Fail2Ban Alert
sender = noreply@yourdomain.com
mta = mail
action = %(action_mwl)s

# Ban settings
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = 22,2222
filter = sshd
logpath = /var/log/secure
maxretry = 3
bantime = 3600
findtime = 600

[recidive]
enabled = true
logpath = /var/log/fail2ban.log
banaction = iptables-allports
bantime = 604800
findtime = 86400
maxretry = 3
EOF

# Fail2ban'ı yeniden başlat
systemctl restart fail2ban

# Test et
fail2ban-client set sshd banip 1.2.3.4
```

---

### Adım 4: Email Formatını Özelleştir (Opsiyonel)

```bash
# Email template'ini düzenle
nano /etc/fail2ban/action.d/mail-whois.conf

# Örnek özelleştirme:
actionban = printf %%b "Subject: [Fail2Ban] <name>: Yasaklandı <ip>
Date: `LC_ALL=C date +"%%a, %%d %%h %%Y %%T %%z"`
From: <sendername> <<sender>>
To: <dest>

🚨 GÜVENLIK UYARISI 🚨

IP Adresi: <ip>
Yasaklama Süresi: <bantime> saniye
Sebep: <failures> başarısız giriş denemesi
Service: <name>
Port: <port>

Detaylar:
<failures>

---
Fail2Ban Automatic Security System
" | /usr/sbin/sendmail -f <sender> <dest>
```

---

## 🎯 Seçenek 2: SendGrid (PROFESYONEl)

### Avantajlar:
- ✅ İlk 100 email/gün ücretsiz
- ✅ API key ile kolay entegrasyon
- ✅ Profesyonel delivery rate
- ✅ Email analytics

### Kurulum:

1. **SendGrid hesabı oluştur:** https://signup.sendgrid.com/
2. **API Key oluştur:**
   - Settings → API Keys → Create API Key
   - Name: `fail2ban-alerts`
   - Permissions: **Full Access** veya **Mail Send**
   - 🔑 API Key'i kopyala: `SG.xxxxxxxxxxxxxx`

3. **Python script ile email gönder:**

```bash
# Python ve pip kur
dnf install -y python3-pip

# SendGrid kütüphanesi kur
pip3 install sendgrid

# Email gönderim scripti oluştur
cat > /usr/local/bin/sendgrid-alert.py << 'EOF'
#!/usr/bin/env python3
import sys
from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail

message = Mail(
    from_email='noreply@yourdomain.com',
    to_emails='your-email@gmail.com',
    subject=sys.argv[1] if len(sys.argv) > 1 else 'Fail2ban Alert',
    html_content=sys.stdin.read())

try:
    sg = SendGridAPIClient('SG.your_api_key_here')
    response = sg.send(message)
    print(f"Email sent: {response.status_code}")
except Exception as e:
    print(f"Error: {e}")
EOF

chmod +x /usr/local/bin/sendgrid-alert.py

# Test
echo "<h1>Test Email</h1>" | /usr/local/bin/sendgrid-alert.py "Test Subject"
```

4. **Fail2ban action düzenle:**

```bash
cat > /etc/fail2ban/action.d/sendgrid.conf << 'EOF'
[Definition]
actionstart =
actionstop =
actioncheck =
actionban = echo "IP <ip> banned for <failures> failures" | /usr/local/bin/sendgrid-alert.py "[Fail2Ban] <name>: Banned <ip>"
actionunban =

[Init]
EOF

# jail.local'de kullan
action = %(action_)s
         sendgrid
```

---

## 🎯 Seçenek 3: Mailgun (ALTERNATİF)

### Avantajlar:
- ✅ İlk 5000 email/ay ücretsiz
- ✅ 3 ay deneme süresi
- ✅ Webhook desteği
- ✅ Email validation API

### Kurulum:

1. **Mailgun hesabı oluştur:** https://signup.mailgun.com/
2. **Domain verify et** (veya sandbox domain kullan)
3. **API Key al:** Settings → API Keys
4. **SMTP Credentials al:**
   - Sending → Domain settings → SMTP credentials
   - SMTP Hostname: `smtp.mailgun.org`
   - Port: `587`
   - Username: `postmaster@your-domain.mailgun.org`
   - Password: (generate edilmiş şifre)

5. **Postfix yapılandır:**

```bash
cat > /etc/postfix/sasl_passwd << EOF
[smtp.mailgun.org]:587 postmaster@your-domain.mailgun.org:your-password-here
EOF

chmod 600 /etc/postfix/sasl_passwd
postmap /etc/postfix/sasl_passwd

cat >> /etc/postfix/main.cf << EOF

# Mailgun SMTP Settings
relayhost = [smtp.mailgun.org]:587
smtp_use_tls = yes
smtp_sasl_auth_enable = yes
smtp_sasl_security_options = noanonymous
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_tls_CAfile = /etc/ssl/certs/ca-bundle.crt
EOF

systemctl restart postfix
```

---

## 🔍 TEST VE DEBUGGING

### Email Gönderimini Test Et:

```bash
# Basit test
echo "Test message" | mail -s "Test Subject" your-email@gmail.com

# Detaylı test (log ile)
echo "Test with logs" | mail -s "Test" your-email@gmail.com && tail -f /var/log/maillog

# Fail2ban test
fail2ban-client set sshd banip 1.2.3.4

# Mail kuyruğunu kontrol et
mailq

# Mail log'larını kontrol et
tail -50 /var/log/maillog
grep "status=" /var/log/maillog | tail -20
```

### Yaygın Sorunlar ve Çözümler:

#### 1. "Relay access denied" hatası
```bash
# Postfix'in relay_domains ayarını kontrol et
postconf relay_domains
# Çözüm: main.cf'e ekle
echo "relay_domains =" >> /etc/postfix/main.cf
systemctl restart postfix
```

#### 2. "Authentication failed" hatası
```bash
# SASL parolasını kontrol et
cat /etc/postfix/sasl_passwd
# Hash'i yeniden oluştur
postmap /etc/postfix/sasl_passwd
systemctl restart postfix
```

#### 3. Gmail "Less secure app" hatası
```bash
# Gmail App Password kullanmadıysanız:
# 1. Google hesabınızda 2FA aktif edin
# 2. App Password oluşturun
# 3. Normal şifre yerine App Password kullanın
```

#### 4. Email gelmiyor
```bash
# Mail log'larını incele
grep "fail2ban" /var/log/maillog
tail -100 /var/log/maillog | grep "to=<your-email@gmail.com>"

# Postfix durumunu kontrol et
systemctl status postfix
postfix check

# DNS ayarlarını kontrol et (SPF, DKIM)
dig +short TXT your-domain.com
```

---

## 📊 EMAIL BİLDİRİM ÖRNEKLERİ

### Ban Bildirimi:
```
Subject: [Fail2Ban] sshd: Yasaklandı 185.220.101.45

🚨 GÜVENLIK UYARISI 🚨

IP Adresi: 185.220.101.45
Yasaklama Süresi: 3600 saniye (1 saat)
Sebep: 5 başarısız SSH giriş denemesi
Service: sshd
Port: 22, 2222
Tarih: 2025-12-10 06:45:23

Başarısız Giriş Denemeleri:
Dec 10 06:44:12 - Failed password for root
Dec 10 06:44:18 - Failed password for admin
Dec 10 06:44:24 - Failed password for user
Dec 10 06:44:30 - Failed password for test
Dec 10 06:44:36 - Failed password for root

Konum: Unknown
ISP: Unknown

---
Fail2Ban Automatic Security System
Server: 31.56.214.200
```

### Unban Bildirimi:
```
Subject: [Fail2Ban] sshd: Yasak Kaldırıldı 185.220.101.45

✅ Yasak Kaldırıldı

IP Adresi: 185.220.101.45
Service: sshd
Yasak Süresi: 3600 saniye (tamamlandı)
Tarih: 2025-12-10 07:45:23

IP adresi tekrar erişim sağlayabilir.
---
Fail2Ban Automatic Security System
```

---

## 🎯 ÖNERİLEN KONFİGÜRASYON (GMAIL)

İşte kullanıma hazır, kopyala-yapıştır komutlar:

```bash
# 1. Gmail App Password ile değiştir
GMAIL_ADDRESS="your-email@gmail.com"
GMAIL_APP_PASSWORD="abcd efgh ijkl mnop"  # 16 haneli app password

# 2. Postfix SMTP ayarla
ssh root@31.56.214.200 << EOF
cat > /etc/postfix/sasl_passwd << INNER
[smtp.gmail.com]:587 ${GMAIL_ADDRESS}:${GMAIL_APP_PASSWORD}
INNER
chmod 600 /etc/postfix/sasl_passwd
postmap /etc/postfix/sasl_passwd

cat >> /etc/postfix/main.cf << INNER

# Gmail SMTP Configuration
relayhost = [smtp.gmail.com]:587
smtp_use_tls = yes
smtp_sasl_auth_enable = yes
smtp_sasl_security_options = noanonymous
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_tls_CAfile = /etc/ssl/certs/ca-bundle.crt
smtp_tls_loglevel = 1
INNER

systemctl restart postfix
systemctl enable postfix

# 3. Fail2ban email ayarları
cat > /etc/fail2ban/jail.local << INNER
[DEFAULT]
destemail = ${GMAIL_ADDRESS}
sendername = Fail2Ban Security Alert
sender = fail2ban@31-56-214-200.verisunucu.net
mta = mail
action = %(action_mwl)s
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = 22,2222
filter = sshd
logpath = /var/log/secure
maxretry = 3
bantime = 3600
findtime = 600

[recidive]
enabled = true
logpath = /var/log/fail2ban.log
banaction = iptables-allports
bantime = 604800
findtime = 86400
maxretry = 3
INNER

systemctl restart fail2ban

# 4. Test email gönder
echo "Fail2ban email notification system test" | mail -s "[TEST] Fail2ban Alert System" ${GMAIL_ADDRESS}

# 5. Test ban (fake IP)
fail2ban-client set sshd banip 1.2.3.4

echo "✅ Email bildirim sistemi kuruldu!"
echo "📧 ${GMAIL_ADDRESS} adresine test email'i kontrol edin"
EOF
```

---

## 📈 MALİYET KARŞILAŞTIRMA

| Sağlayıcı | Ücretsiz Limit | Aylık Maliyet | Önerilen |
|-----------|----------------|---------------|----------|
| **Gmail SMTP** | 500 email/gün | $0 | ⭐⭐⭐⭐⭐ |
| **SendGrid** | 100 email/gün | $0 | ⭐⭐⭐⭐ |
| **Mailgun** | 5000 email/ay | $0 (3 ay) | ⭐⭐⭐ |
| **AWS SES** | 62,000 email/ay | $0.10/1000 | ⭐⭐ |
| **Mailchimp** | 500 email/ay | $0 | ⭐⭐ |

**Fail2ban için ortalama email:** ~5-10 email/gün (normal kullanımda)

---

## ✅ KONTROL LİSTESİ

- [ ] Gmail hesabında 2FA aktif
- [ ] Gmail App Password oluşturuldu
- [ ] Postfix kurulu ve çalışıyor
- [ ] SMTP ayarları yapılandırıldı
- [ ] Test email gönderildi ve alındı
- [ ] Fail2ban email ayarları güncellendi
- [ ] Test ban yapıldı ve email geldi
- [ ] Mail log'ları kontrol edildi
- [ ] Email spam klasörü kontrol edildi

---

**💡 İpucu:** Gmail ilk email'leri spam klasörüne atabilir. "Not spam" olarak işaretleyin.

**🔐 Güvenlik:** App Password'ü asla paylaşmayın. Şüphe duyarsanız yeniden oluşturun.

**📧 Rapor Tarihi:** 10 Aralık 2025  
**Kurulum Süresi:** ~5-10 dakika
