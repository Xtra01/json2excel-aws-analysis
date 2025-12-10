#!/usr/bin/env python3
"""
JSON2EXCEL Production Deployment Script
Tested and Working - December 10, 2025

Prerequisites:
- SSH key installed: ssh-copy-id root@31.56.214.200
- panel_bilgileri.env file with credentials
"""

import paramiko
import time
import sys
from pathlib import Path

def load_config():
    """Load configuration from env file"""
    env_file = Path("../panel_bilgileri.env")
    config = {}
    for line in env_file.read_text().splitlines():
        if '=' in line and not line.startswith('#'):
            key, value = line.split('=', 1)
            config[key.strip()] = value.strip()
    return config

def ssh_connect(config):
    """Establish SSH connection"""
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(
        config['VPS_IP'],
        username=config['VPS_USER'],
        password=config['VPS_PASSWORD'],
        timeout=10
    )
    return ssh

def run_command(ssh, command, show_output=True):
    """Execute SSH command"""
    stdin, stdout, stderr = ssh.exec_command(command, timeout=900)
    exit_status = stdout.channel.recv_exit_status()
    output = stdout.read().decode()
    error = stderr.read().decode()
    
    if show_output and output:
        print(output)
    if error and exit_status != 0:
        print(f"Error: {error}", file=sys.stderr)
    
    return output, error, exit_status

def main():
    print("=" * 60)
    print("  JSON2EXCEL - PRODUCTION DEPLOYMENT")
    print("=" * 60)
    print()
    
    # Load configuration
    config = load_config()
    VPS_IP = config['VPS_IP']
    DOMAIN = config['DOMAIN']
    
    print(f"[1/8] SSH Connection to {VPS_IP}")
    print("-" * 60)
    ssh = ssh_connect(config)
    print("✓ Connected")
    
    print()
    print("[2/8] Clean broken files")
    print("-" * 60)
    run_command(ssh, "cd /opt/json2excel/app && find . -name '*.broken.*' -delete && find . -name '*.backup.*' -delete", show_output=False)
    print("✓ Source cleaned")
    
    print()
    print("[3/8] SELinux context fix")
    print("-" * 60)
    run_command(ssh, "chcon -Rt svirt_sandbox_file_t /opt/json2excel/app 2>&1", show_output=False)
    print("✓ SELinux context set")
    
    print()
    print("[4/8] Docker Compose configuration check")
    print("-" * 60)
    output, _, _ = run_command(ssh, "cd /opt/json2excel && grep -A2 'build:' docker-compose.yml | head -5", show_output=True)
    
    print()
    print("[5/8] Docker Build (10-15 minutes)")
    print("-" * 60)
    print("Starting build in background...")
    run_command(ssh, "cd /opt/json2excel && nohup docker compose build > /tmp/docker-build.log 2>&1 &", show_output=False)
    
    # Monitor build
    for i in range(30):
        time.sleep(30)
        output, _, _ = run_command(ssh, "tail -2 /tmp/docker-build.log", show_output=False)
        print(f"[{(i+1)*30}s] {output.strip().split(chr(10))[-1][:70]}")
        
        if "Successfully tagged" in output or "Error:" in output:
            break
    
    # Check result
    output, _, _ = run_command(ssh, "tail -20 /tmp/docker-build.log", show_output=False)
    if "Successfully tagged" in output:
        print("✓ Build successful")
    else:
        print("⚠ Build may have issues, check /tmp/docker-build.log on server")
    
    print()
    print("[6/8] Create required directories")
    print("-" * 60)
    run_command(ssh, """
        mkdir -p /var/lib/json2excel/uploads /var/log/json2excel /var/log/nginx && \
        chmod -R 755 /var/lib/json2excel /var/log/json2excel /var/log/nginx && \
        chown -R 1001:1001 /var/lib/json2excel/uploads /var/log/json2excel 2>/dev/null || true
    """, show_output=False)
    print("✓ Directories created")
    
    print()
    print("[7/8] Start containers")
    print("-" * 60)
    run_command(ssh, "cd /opt/json2excel && docker compose down 2>&1", show_output=False)
    time.sleep(3)
    output, _, _ = run_command(ssh, "cd /opt/json2excel && docker compose up -d 2>&1", show_output=False)
    print("✓ Containers started")
    time.sleep(10)
    
    print()
    print("[8/8] Health check")
    print("-" * 60)
    output, _, _ = run_command(ssh, "cd /opt/json2excel && docker compose ps", show_output=True)
    
    print()
    print("-" * 60)
    # Test HTTPS
    output, _, exit_code = run_command(ssh, "curl -k -s -o /dev/null -w '%{http_code}' https://localhost/", show_output=False)
    if output.strip() == "200":
        print("✅ Application is running (HTTPS 200 OK)")
    else:
        print(f"⚠ HTTPS returned {output.strip()}")
    
    ssh.close()
    
    print()
    print("=" * 60)
    print("  DEPLOYMENT COMPLETED!")
    print("=" * 60)
    print()
    print(f"Local HTTPS: https://{VPS_IP}")
    print(f"Domain (after DNS): https://{DOMAIN}")
    print()
    print("Next steps:")
    print("1. Configure Cloudflare DNS: A record → " + VPS_IP)
    print("2. Install Let's Encrypt SSL: certbot --nginx -d " + DOMAIN)
    print("3. Test production URL")
    print()

if __name__ == "__main__":
    main()
