# 🚀 JSON2Excel Deployment & AWS Cloud Comparison

Bu repository, JSON2Excel projesinin production deployment dosyalarını ve AWS cloud karşılaştırma analizlerini içerir.

## 📋 İçerik

### 1. **AWS Fiyatlandırma Analizleri**
- [AWS En Ucuz Fiyatlandırma Raporu](AWS-EN-UCUZ-PRICING-RAPORU.md) - AWS'de en düşük maliyetli hosting seçenekleri
- [Cloud Karşılaştırma Analizi](cloud-comparison-analysis.md) - AWS vs VDS vs Hetzner vs DigitalOcean

### 2. **Production Deployment**
- [Production Ready Package](production-ready/) - Tüm deployment scriptleri ve dokümantasyonları
  - Otomatik yedekleme sistemi
  - Docker cleanup otomasyonu
  - Container recovery sistemi
  - System watchdog
  - Monitoring ve logging

### 3. **JSON2Excel Deployment**
- [Deployment Scripts](json2excel-deployment/scripts/) - Production deployment scriptleri
- [Configuration Files](json2excel-deployment/configs/) - Nginx, Docker Compose, systemd configs
- [Documentation](json2excel-deployment/docs/) - Kurulum ve kullanım kılavuzları

## 🏆 Öne Çıkan Özellikler

### Enterprise Backup System
- ✅ Pre-flight disk space checks
- ✅ Size estimation (compress ratio calculation)
- ✅ Atomic operations (temp → verify → rename)
- ✅ Multi-tier retention (daily/weekly/monthly)
- ✅ Integrity verification

### Automation Systems
- 🔄 Docker cleanup (daily at 02:00)
- 🔄 Container recovery (every 5 minutes)
- 🔄 System watchdog (boot recovery)
- 🔄 Enterprise backup (daily at 03:00)

### Monitoring & Logging
- 📊 Centralized logging (rsyslog + journald)
- 📊 Log rotation (7-14 day retention)
- 📊 Disk usage monitoring
- 📊 Container health checks

## 💰 Cost Analysis Summary

| Provider | Monthly Cost | vs AWS |
|----------|-------------|--------|
| **Current VDS** | 254.90 TL (~$7.50) | **46x cheaper** ✅ |
| **Hetzner CX11** | €4.49 (~$5) | **18x cheaper** |
| **AWS Lightsail** | $3.50 (IPv6 only) | Cheapest AWS |
| **AWS EC2 m5.2xlarge** | ~$342 | Baseline |

## 🎯 Quick Start

### View AWS Pricing Analysis
```bash
# Read comprehensive AWS pricing report
cat AWS-EN-UCUZ-PRICING-RAPORU.md

# Compare cloud providers
cat cloud-comparison-analysis.md
```

### Deploy to Production
```bash
# Navigate to deployment directory
cd json2excel-deployment/scripts

# Run setup automation
bash setup-production-automation.sh
```

## 📚 Documentation

- [Automation Guide](production-ready/03-docs/AUTOMATION-GUIDE.md)
- [Backup System Guide](production-ready/03-docs/BACKUP-SYSTEM-GUIDE.md)
- [Restore Guide](production-ready/03-docs/RESTORE-GUIDE.md)
- [Troubleshooting Guide](production-ready/03-docs/TROUBLESHOOTING.md)

## 🔐 Security Notes

⚠️ **This repository does NOT contain:**
- Passwords or secrets
- Private keys or certificates
- API keys or tokens
- Database credentials
- SSH keys

All sensitive data is excluded via `.gitignore`.

## 📊 Project Status

- ✅ Production deployment completed
- ✅ Automation systems operational
- ✅ Backup system tested (96 MB backups created)
- ✅ Disk optimization (18 GB → 5.6 GB)
- ✅ Documentation comprehensive (7 guides, 60 KB)

## 🚀 Technologies Used

- **OS:** AlmaLinux 8.10
- **Container:** Podman 4.9.4
- **Automation:** Bash, Systemd, Cron
- **Logging:** Rsyslog, Journald
- **Monitoring:** CloudWatch-style metrics
- **Backup:** Tar.gz with verification

## 📈 Performance Metrics

- **Disk Usage:** 5.6 GB / 118 GB (5%)
- **Backup Size:** 96 MB (compressed)
- **Cleanup Efficiency:** 13 GB recovered
- **Uptime:** 99.9%+ (with auto-recovery)

## 🤝 Contributing

This is a personal project repository. For issues or suggestions:
- Open an issue on GitHub
- Contact via repository discussions

## 📄 License

This project is for personal/educational use. All rights reserved.

---

**Last Updated:** December 10, 2025  
**Author:** Xtra01  
**Repository:** [github.com/Xtra01/json2excel-deployment](https://github.com/Xtra01/json2excel-deployment)
