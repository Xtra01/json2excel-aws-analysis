# Cloudflare DNS Manual Setup
## json2excel.devtestenv.org

### Step 1: Login to Cloudflare
URL: https://dash.cloudflare.com/2c596d737d8b39d20df20b66f94197e9/devtestenv.org/dns/records

### Step 2: Add DNS Record
```
Type: A
Name: json2excel
IPv4 address: 31.56.214.200
Proxy status: Proxied (orange cloud ON)
TTL: Auto
```

### Step 3: Verify
Wait 2-5 minutes, then test:
```bash
nslookup json2excel.devtestenv.org
# Should return Cloudflare proxy IP

curl -I https://json2excel.devtestenv.org
# Should return 200 OK (self-signed warning normal)
```

### Step 4: Install Let's Encrypt SSL
```bash
ssh root@31.56.214.200
certbot --nginx -d json2excel.devtestenv.org --non-interactive --agree-tos --email admin@devtestenv.org --redirect
cd /opt/json2excel && docker compose restart nginx
```

### Step 5: Final Test
```bash
curl -I https://json2excel.devtestenv.org
# Should return 200 OK with valid SSL
```

### Troubleshooting

**DNS not resolving:**
- Check Cloudflare dashboard for record
- Wait 5-10 minutes for propagation
- Test: `dig json2excel.devtestenv.org`

**SSL cert failed:**
- Ensure DNS is fully propagated first
- Check nginx is running: `docker ps | grep nginx`
- Check ports open: `ss -tlnp | grep :80`

**502 Bad Gateway:**
- Check app container: `docker compose logs json2excel-app`
- Restart containers: `docker compose restart`
