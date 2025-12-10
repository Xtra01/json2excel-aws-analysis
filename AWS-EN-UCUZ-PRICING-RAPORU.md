# 💰 AWS En Ucuz Fiyatlandırma Raporu 2025

## 📋 Executive Summary

AWS'de **en düşük maliyetli** hosting seçenekleri araştırıldı. Bu rapor, küçük ve orta ölçekli projeler için **en uygun maliyetli AWS çözümlerini** detaylı olarak analiz eder.

**🎯 Sonuç:** AWS Lightsail (IPv6 Only) en ucuz seçenek: **$3.50/ay**

---

## 🏆 EN UCUZ AWS SEÇENEKLERİ (Sıralı)

### 1. 🥇 **AWS Free Tier** (İlk 12 Ay)
**Fiyat:** $0/ay (750 saat/ay ücretsiz)

#### Ne Dahil?
- **EC2 t2.micro instance:** 1 vCPU, 1 GB RAM
- **750 saat/ay:** Neredeyse tüm ay boyunca 7/24 çalışabilir
- **30 GB EBS Storage:** Genel amaçlı SSD (gp2 veya gp3)
- **15 GB bandwidth:** Dışarı veri transferi
- **1 Elastic IP:** Sabit IP adresi

#### Sınırlamalar:
- ⚠️ **Sadece yeni müşteriler** (ilk 12 ay)
- ⚠️ **t2.micro only:** Zayıf performans (burstable CPU)
- ⚠️ **Tek instance:** Birden fazla sunucu için geçerli değil
- ⚠️ **EBS fazla kullanım ücretli:** 30 GB sonrası $0.10/GB

#### Uygun Kullanım:
✅ Test/development ortamları  
✅ Düşük trafikli blog/website  
✅ Basit backend API  
✅ Learning/POC projeler  

---

### 2. 🥈 **AWS Lightsail (IPv6 Only)**
**Fiyat:** $3.50/ay

#### Özellikler:
- **CPU:** 2 vCPU (burstable)
- **RAM:** 512 MB
- **Disk:** 20 GB NVMe SSD
- **Bandwidth:** 1 TB ücretsiz transfer
- **Network:** 10 Gbps
- **IPv6 Only:** Public IPv4 yok (bu yüzden ucuz)

#### Dahil Özellikler:
✅ Static IP (IPv6)  
✅ DNS management  
✅ SSH/RDP terminal  
✅ Server monitoring  
✅ DDoS protection  
✅ Backup ($0.05/GB)  

#### İlk 3 Ay Ücretsiz Promosyon:
🎁 Yeni hesaplar için ilk 3 ay **BEDAVA**

#### Ek Maliyetler:
- Backup snapshots: **$0.05/GB/ay**
- Bandwidth aşımı: **$0.09/GB** (1 TB sonrası)
- IPv4 adresi: **+$2/ay** (opsiyonel)

#### Uygun Kullanım:
✅ Küçük web apps  
✅ API sunucuları  
✅ Dev/test ortamları  
✅ IPv6 destekli projeler  

❌ **Uygun Değil:**
- Legacy sistemler (IPv4 zorunlu)
- Yüksek CPU gereksinimleri
- 512 MB RAM'den fazla gerek

---

### 3. 🥉 **AWS Lightsail (IPv4 Dahil)**
**Fiyat:** $5/ay

#### Özellikler:
- **CPU:** 2 vCPU (burstable)
- **RAM:** 512 MB
- **Disk:** 20 GB NVMe SSD
- **Bandwidth:** 1 TB ücretsiz transfer
- **Public IPv4:** ✅ Dahil
- **IPv6:** ✅ Dahil (dual-stack)

#### $3.50 Plana Göre Fark:
- **+$1.50/ay:** Public IPv4 adresi için
- Diğer tüm özellikler aynı

#### İlk 3 Ay Ücretsiz Promosyon:
🎁 Yeni hesaplar için ilk 3 ay **BEDAVA**

#### Uygun Kullanım:
✅ Tüm IPv4 ihtiyaçları  
✅ Legacy app'ler  
✅ WordPress, Node.js, Python apps  
✅ Basit e-ticaret  

---

### 4. **AWS EC2 t4g.nano (Graviton2)**
**Fiyat:** ~$3.80/ay (On-Demand)

#### Özellikler:
- **CPU:** 2 vCPU (ARM Graviton2)
- **RAM:** 512 MB
- **Burstable Performance:** CPU Credits
- **ARM Mimari:** x86 değil, ARM64

#### Ek Maliyetler:
- **EBS Storage (8 GB gp3):** $0.80/ay
- **IPv4 Adresi:** $3.60/ay
- **Bandwidth (ilk 100 GB sonrası):** $0.09/GB

**Toplam Minimum:** ~**$8.20/ay**

#### Spot Instance Fiyatı:
- **Spot:** ~$1.14/ay (70% tasarruf)
- ⚠️ **Riski:** AWS istediği zaman kapatabilir

#### Avantajları:
- ✅ ARM işlemci (güç tasarrufu)
- ✅ Daha ucuz (x86'ya göre)
- ✅ Esnek konfigürasyon

#### Dezavantajları:
- ❌ ARM uyumluluk sorunları (bazı yazılımlar)
- ❌ Karmaşık fiyatlandırma (EBS + IP + traffic)
- ❌ Lightsail'den daha pahalı

---

### 5. **AWS EC2 t3a.nano (AMD)**
**Fiyat:** ~$4.25/ay (On-Demand)

#### Özellikler:
- **CPU:** 2 vCPU (AMD EPYC)
- **RAM:** 512 MB
- **x86_64 Mimari:** Tüm yazılımlarla uyumlu

#### Ek Maliyetler:
- **EBS Storage (8 GB gp3):** $0.80/ay
- **IPv4 Adresi:** $3.60/ay
- **Bandwidth:** $0.09/GB (100 GB sonrası)

**Toplam Minimum:** ~**$8.65/ay**

#### Spot Instance Fiyatı:
- **Spot:** ~$1.28/ay (70% tasarruf)

#### t4g.nano ile Karşılaştırma:
- **+$0.45/ay daha pahalı** (On-Demand)
- ✅ x86 uyumlu (ARM değil)
- ✅ Daha yaygın destek

---

### 6. **AWS EC2 t3.micro (Intel)**
**Fiyat:** ~$8.50/ay (On-Demand)

#### Özellikler:
- **CPU:** 2 vCPU (Intel Xeon)
- **RAM:** 1 GB (512 MB değil!)
- **x86_64 Mimari**
- **Burstable Performance**

#### Ek Maliyetler:
- **EBS Storage (8 GB gp3):** $0.80/ay
- **IPv4 Adresi:** $3.60/ay

**Toplam Minimum:** ~**$12.90/ay**

#### Spot Instance Fiyatı:
- **Spot:** ~$2.55/ay (70% tasarruf)

#### Free Tier:
🎁 **İlk 12 ay 750 saat/ay ücretsiz** (t2.micro - benzer spec)

#### Neden Seçilir?
- ✅ **1 GB RAM** (512 MB değil)
- ✅ Intel işlemci (en yaygın)
- ✅ Tüm yazılımlarla uyumlu

---

## 📊 Detaylı Fiyat Karşılaştırması

| Seçenek | Aylık | CPU | RAM | Disk | IPv4 | Bandwidth | İlk Maliyet |
|---------|-------|-----|-----|------|------|-----------|-------------|
| **Free Tier (t2.micro)** | **$0** | 1 vCPU | 1 GB | 30 GB | ✅ | 15 GB | $0 (12 ay) |
| **Lightsail IPv6** | **$3.50** | 2 vCPU | 512 MB | 20 GB | ❌ | 1 TB | $0 (3 ay ücretsiz) |
| **t4g.nano (Spot)** | **$1.14** | 2 vCPU ARM | 512 MB | 8 GB* | $3.60* | 100 GB | **$5.54/ay** |
| **t3a.nano (Spot)** | **$1.28** | 2 vCPU AMD | 512 MB | 8 GB* | $3.60* | 100 GB | **$5.68/ay** |
| **Lightsail IPv4** | **$5** | 2 vCPU | 512 MB | 20 GB | ✅ | 1 TB | $0 (3 ay ücretsiz) |
| **t4g.nano (On-Demand)** | **$3.80** | 2 vCPU ARM | 512 MB | 8 GB* | $3.60* | 100 GB | **$8.20/ay** |
| **t3a.nano (On-Demand)** | **$4.25** | 2 vCPU AMD | 512 MB | 8 GB* | $3.60* | 100 GB | **$8.65/ay** |
| **t3.micro (Spot)** | **$2.55** | 2 vCPU Intel | 1 GB | 8 GB* | $3.60* | 100 GB | **$6.95/ay** |
| **t3.micro (On-Demand)** | **$8.50** | 2 vCPU Intel | 1 GB | 8 GB* | $3.60* | 100 GB | **$12.90/ay** |

*EBS ve IPv4 ücretleri ayrıca

---

## 💡 TAVSİYELER (Senaryoya Göre)

### 🎓 **Öğrenme / Test / POC**
**Seçim:** AWS Free Tier (t2.micro)
- **Neden:** Tamamen ücretsiz (12 ay)
- **Maliyet:** $0/ay
- **Yeter mi:** Evet, learning için fazlasıyla yeterli

---

### 🚀 **Küçük Production App (IPv6 OK)**
**Seçim:** AWS Lightsail IPv6 Only ($3.50/ay)
- **Neden:** En ucuz production seçenek
- **Avantajlar:**
  - 1 TB bandwidth dahil
  - 20 GB NVMe SSD
  - Monitoring dahil
  - İlk 3 ay ücretsiz
- **Dezavantajlar:**
  - IPv4 yok
  - 512 MB RAM sınırlı

---

### 🌐 **Küçük Production App (IPv4 Gerekli)**
**Seçim:** AWS Lightsail IPv4 ($5/ay)
- **Neden:** Dual-stack (IPv4 + IPv6), basit fiyatlandırma
- **Avantajlar:**
  - Tüm Lightsail özellikleri
  - Public IPv4
  - 1 TB bandwidth
  - İlk 3 ay ücretsiz
- **Alternatif:** t3.micro Spot ($6.95/ay toplam) - Daha fazla RAM (1 GB)

---

### 💪 **Orta Ölçekli App (Daha Fazla RAM)**
**Seçim:** Lightsail $7/ay (1 GB RAM, 2 vCPU, 40 GB disk)
- **Neden:** Hala basit, tahmin edilebilir
- **Avantajlar:**
  - 2x RAM (1 GB)
  - 2x Disk (40 GB)
  - 2 TB bandwidth
- **Alternatif:** EC2 t3.small (2 GB RAM) - Daha pahalı (~$15/ay)

---

### 🎯 **Maliyet Optimize (Risk Kabul)**
**Seçim:** EC2 Spot Instances
- **t3.micro Spot:** $2.55/ay + $3.60 IP + $0.80 EBS = **$6.95/ay**
- **Neden:** %70 tasarruf
- **Risk:** AWS 2 dakika önceden uyararak kapatabilir
- **Uygun:** Stateless apps, container'lar, background jobs

---

## ⚠️ GİZLİ MALİYETLER (Dikkat!)

### 1. **IPv4 Adresi ($3.60/ay)**
- AWS artık **tüm public IPv4 adreslerinden** ücret alıyor
- EC2 için **zorunlu ek maliyet**
- Lightsail'de bazı planlar IPv4 dahil, bazıları değil

### 2. **EBS Storage**
- EC2 için **disk ayrıca ücretli**
- gp3 (yeni): **$0.08/GB/ay**
- 10 GB minimum → **$0.80/ay**
- Snapshot: **$0.05/GB/ay**

### 3. **Data Transfer (Bandwidth)**
- **İlk 100 GB/ay ücretsiz** (tüm AWS servisleri toplamda)
- Sonrası: **$0.09/GB**
- **Örnek:** 500 GB trafik = 400 GB × $0.09 = **$36/ay**

### 4. **Elastic IP (Kullanılmayan)**
- Atanmış ama kullanılmayan IP: **$3.60/ay**
- Instance durdurulduğunda ücret devam eder

### 5. **CloudWatch Monitoring**
- Basic: Ücretsiz (5 dakikalık metrik)
- Detailed: **$2.10/instance/ay** (1 dakikalık metrik)

### 6. **Load Balancer**
- Application LB: **$16.20/ay** + $0.008/LCU
- Lightsail LB: **$18/ay** (sabit fiyat)

---

## 📈 SENARYO BAZLI MALİYET ANALİZİ

### Senaryo 1: Basit Blog/Website
**Gereksinimler:** 1 GB RAM, 20 GB disk, 500 GB/ay trafik

| Seçenek | Hesaplama | Aylık |
|---------|-----------|-------|
| **Free Tier** | $0 (12 ay) | **$0** |
| **Lightsail $5** | $5 (1 TB dahil) | **$5** |
| **t3.micro On-Demand** | $8.50 + $3.60 + $0.80 + ($400GB × $0.09) | **$48.90** |
| **t3.micro Spot** | $2.55 + $3.60 + $0.80 + $36 | **$42.95** |

**Tavsiye:** Lightsail $5 ⭐ (basit, tahmin edilebilir)

---

### Senaryo 2: JSON2Excel API (Sizin Proje)
**Gereksinimler:** 4 CPU, 32 GB RAM, 100 GB disk, 2 TB/ay trafik

| Seçenek | Hesaplama | Aylık |
|---------|-----------|-------|
| **Mevcut VDS** | - | **254.90 TL ($7.50)** |
| **Lightsail $164** | 32 GB, 8 vCPU, 640 GB, 7 TB | **$164 (~5,576 TL)** |
| **EC2 m5.2xlarge** | $330 + $8 + $3.60 + ($1.9 TB × $0.09) | **$512.70 (~17,431 TL)** |
| **EC2 m5.2xlarge Spot** | $99 + $8 + $3.60 + $171 | **$281.60 (~9,574 TL)** |

**Tavsiye:** Mevcut VDS'de kalın! ⭐ AWS 22-68x daha pahalı

---

### Senaryo 3: Microservice (Container)
**Gereksinimler:** 1 GB RAM, Docker, CI/CD

| Seçenek | Hesaplama | Aylık |
|---------|-----------|-------|
| **Lightsail Container (Micro)** | 0.25 vCPU, 1 GB RAM | **$10** |
| **Lightsail Container (Small)** | 0.5 vCPU, 1 GB RAM | **$15** |
| **ECS Fargate** | 0.25 vCPU, 0.5 GB RAM × 730h | **$11.57** |

**Tavsiye:** Lightsail Container Micro ⭐ (basit management)

---

## 🔍 AWS vs Alternatifler (Hızlı Karşılaştırma)

| Özellik | AWS Lightsail $5 | Hetzner CX11 | DigitalOcean $6 | Vultr $6 |
|---------|------------------|---------------|-----------------|----------|
| **CPU** | 2 vCPU | 1 vCPU | 1 vCPU | 1 vCPU |
| **RAM** | 512 MB | 2 GB | 1 GB | 1 GB |
| **Disk** | 20 GB | 20 GB | 25 GB | 25 GB |
| **Bandwidth** | 1 TB | 20 TB | 1 TB | 1 TB |
| **Fiyat** | **$5/ay** | **€4.49/ay (~$5)** | **$6/ay** | **$6/ay** |
| **Lokasyon** | Global | Almanya | Global | Global |

**Sonuç:** Hetzner aynı fiyata **4x daha fazla RAM** veriyor!

---

## 🎯 SON TAVSİYE

### ✅ **AWS Kullanılacaksa:**

1. **Test/Learning:** Free Tier (t2.micro) - $0/ay
2. **Küçük Prod (IPv6 OK):** Lightsail IPv6 Only - $3.50/ay
3. **Küçük Prod (IPv4):** Lightsail IPv4 - $5/ay
4. **Orta Prod:** Lightsail $12 (2 GB RAM) - $12/ay
5. **Maliyet Optimize:** EC2 Spot + Reserved - %70 tasarruf

### ❌ **AWS Kullanılmayacaksa:**

**Alternatifler (Daha Ucuz & Daha İyi):**
1. **Hetzner Cloud:** €4.49/ay (2 GB RAM, 20 TB bandwidth)
2. **DigitalOcean:** $6/ay (1 GB RAM, basit)
3. **Vultr:** $6/ay (1 GB RAM, global)
4. **Sizin VDS:** 254.90 TL/ay (~$7.50) - Zaten en iyi seçim!

---

## 📌 ÖNEMLİ NOTLAR

### 1. **Free Tier Sınırları**
- **Sadece yeni hesaplar** (12 ay)
- **Kullanılmazsa yok olur** (roll over yok)
- **Organizasyon hesabında paylaşılmaz**
- **Dikkat:** Fazla kullanım otomatik ücretlendirilir

### 2. **Lightsail Sınırları**
- **Bandwidth dahil** (EC2'den fark)
- **Basit fiyatlandırma** (sürpriz yok)
- **Sınırlı scaling** (max 256 GB RAM)
- **Managed servisler sınırlı** (RDS, Lambda yok)

### 3. **Spot Instances Riskleri**
- **AWS istediği zaman kapatabilir** (2 dakika uyarı)
- **Stateful app'ler için uygun değil**
- **High availability gereksinimleri varsa kullanma**

### 4. **Region Farkları**
- **us-east-1 (N. Virginia):** Genelde en ucuz
- **eu-central-1 (Frankfurt):** %5-10 daha pahalı
- **ap-south-1 (Mumbai):** Bandwidth yarı fiyat dahil

---

## 🔐 GÜVENLİK ÖNERİLERİ

### Bedava/Ucuz AWS Kullanırken:

1. ✅ **Billing alerts kurun** ($5, $10, $25 threshold)
2. ✅ **IAM kullanıcıları oluşturun** (root kullanmayın)
3. ✅ **MFA aktif edin** (2FA)
4. ✅ **Security groups kısıtlayın** (0.0.0.0/0 yok)
5. ✅ **CloudWatch logs açın** (debugging için)
6. ✅ **Backup alın** (Snapshot her gün)
7. ⚠️ **Kredi kartı limit koyun** (beklenmedik ücretler için)

---

## 📱 HIZLI KARAR AĞACI

```
AWS kullanacak mısınız?
│
├─ Evet → Neden?
│   │
│   ├─ Test/Learning → FREE TIER (t2.micro) $0 ✅
│   │
│   ├─ Küçük Prod
│   │   ├─ IPv6 OK → Lightsail IPv6 $3.50 ✅
│   │   └─ IPv4 gerekli → Lightsail IPv4 $5 ✅
│   │
│   ├─ Orta Prod → Lightsail $12 (2 GB RAM) ✅
│   │
│   └─ Enterprise → Reserved Instances + Savings Plans
│
└─ Hayır → Nereye?
    │
    ├─ En ucuz → Hetzner €4.49 (2 GB RAM) ⭐
    ├─ Basit → DigitalOcean $6 (1 GB RAM)
    ├─ Global → Vultr $6 (1 GB RAM)
    └─ Türkiye → Mevcut VDS 254.90 TL ⭐⭐⭐
```

---

## 💎 ÖZET TABLO

| Durum | En İyi Seçenek | Fiyat | Neden |
|-------|----------------|-------|-------|
| **Test/POC** | AWS Free Tier | **$0/ay** | 12 ay ücretsiz |
| **Küçük App (IPv6)** | Lightsail IPv6 | **$3.50/ay** | En ucuz production |
| **Küçük App (IPv4)** | Lightsail IPv4 | **$5/ay** | Basit, tahmin edilebilir |
| **Orta App** | Lightsail $12 | **$12/ay** | 2 GB RAM dahil |
| **AWS Dışı** | Hetzner CX11 | **€4.49/ay** | 4x daha fazla RAM |
| **JSON2Excel** | **Mevcut VDS** | **254.90 TL** | 46x ucuz AWS'den ⭐ |

---

## 🎓 SONUÇ

**AWS'de en ucuz seçenek:**
1. **Free Tier** - $0/ay (12 ay, yeni hesaplar)
2. **Lightsail IPv6 Only** - $3.50/ay (production)
3. **Lightsail IPv4** - $5/ay (klasik)

**Ama unutmayın:**
- AWS **karmaşık fiyatlandırma** (gizli ücretler)
- Alternatifler **genelde daha ucuz** (Hetzner, DO, Vultr)
- **Sizin VDS zaten mükemmel** (254.90 TL = AWS'nin 1/46'sı)

**Tavsiye:** AWS sadece enterprise/global scaling gerektiğinde. Küçük projeler için Hetzner/DO/Mevcut VDS kullanın!

---

**Rapor Tarihi:** 10 Aralık 2025  
**Kur:** 1 USD = 34 TL  
**Kaynak:** AWS Resmi Fiyatlandırma Sayfaları, Lightsail Pricing, EC2 Pricing

