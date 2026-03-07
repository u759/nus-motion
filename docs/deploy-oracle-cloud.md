# NUS Motion Backend — Oracle Cloud Free Tier Deployment Guide

> **Target:** Oracle Cloud Free Tier VM (1GB RAM, ARM Ampere A1 or AMD E2.1)  
> **Stack:** Spring Boot 4, Java 21, Caddy (HTTPS reverse proxy)

This guide deploys the NUS Motion Spring Boot backend on a resource-constrained VM with automatic HTTPS via Let's Encrypt.

---

## Prerequisites

### 1. Oracle Cloud VM Setup
1. Create a Free Tier compute instance:
   - **Shape:** VM.Standard.A1.Flex (ARM) or VM.Standard.E2.1.Micro (AMD)
   - **Memory:** 1GB RAM
   - **Image:** Oracle Linux 9 or Ubuntu 22.04 (both work; this guide uses Ubuntu)
   - **Boot volume:** 50GB (default)

2. Note the **Public IP Address** from the instance details page.

3. Download the SSH private key during instance creation.

### 2. Domain Pointing to VM IP
Point your domain (e.g., `api.nusmotion.example.com`) to the VM's public IP:

```
Type: A
Name: api (or @ for root domain)
Value: <YOUR_VM_PUBLIC_IP>
TTL: 300
```

**DNS propagation takes 5–30 minutes.** Verify with:
```bash
dig +short api.nusmotion.example.com
```

### 3. SSH Access
```bash
chmod 400 ~/oracle-cloud-key.pem
ssh -i ~/oracle-cloud-key.pem ubuntu@<YOUR_VM_PUBLIC_IP>
```

---

## Step 1: Install Java 21

### Ubuntu 22.04+
```bash
sudo apt update
sudo apt install -y openjdk-21-jdk-headless
java -version
```

### Oracle Linux 9
```bash
sudo dnf install -y java-21-openjdk-headless
java -version
```

Verify output shows `openjdk 21.x.x`.

---

## Step 2: JVM Memory Tuning for 1GB RAM

With only 1GB total RAM, the memory budget is:
| Component | RAM Allocation |
|-----------|----------------|
| OS & buffers | ~300MB |
| Caddy (reverse proxy) | ~30MB |
| JVM heap + metaspace | ~500MB |
| Headroom | ~170MB |

### Recommended JVM Options

Create an environment file for the service:

```bash
sudo mkdir -p /etc/nusmotion
sudo nano /etc/nusmotion/jvm.conf
```

Add:
```bash
# JVM options for 1GB RAM environment
JAVA_OPTS="-Xms256m -Xmx400m \
  -XX:+UseSerialGC \
  -XX:MaxMetaspaceSize=64m \
  -XX:+ExitOnOutOfMemoryError \
  -Djava.security.egd=file:/dev/./urandom"
```

**Options explained:**
| Option | Purpose |
|--------|---------|
| `-Xms256m` | Initial heap size (start small) |
| `-Xmx400m` | Maximum heap size (hard limit) |
| `-XX:+UseSerialGC` | Single-threaded GC; lowest memory overhead |
| `-XX:MaxMetaspaceSize=64m` | Limit class metadata memory |
| `-XX:+ExitOnOutOfMemoryError` | Crash cleanly on OOM (systemd restarts) |
| `-Djava.security.egd=...` | Faster startup (non-blocking entropy) |

> **Note:** Serial GC adds ~50ms pause time during garbage collection but uses 50% less memory than G1GC. Acceptable for a low-traffic API.

---

## Step 3: Build the JAR Locally

On your **development machine** (not the VM):

```bash
cd backend
./mvnw clean package -DskipTests
```

The JAR is at: `target/backend-0.0.1-SNAPSHOT.jar`

### Upload to VM
```bash
scp -i ~/oracle-cloud-key.pem \
  target/backend-0.0.1-SNAPSHOT.jar \
  ubuntu@<YOUR_VM_PUBLIC_IP>:/home/ubuntu/
```

---

## Step 4: Create Application Directory

On the VM:

```bash
sudo mkdir -p /opt/nusmotion
sudo mv /home/ubuntu/backend-0.0.1-SNAPSHOT.jar /opt/nusmotion/app.jar
sudo chown -R ubuntu:ubuntu /opt/nusmotion
```

### Create application.properties

```bash
sudo nano /opt/nusmotion/application.properties
```

Add your production config:
```properties
# Server
server.port=8080

# Logging (reduce verbosity in prod)
logging.level.root=WARN
logging.level.com.nusmotion=INFO

# Cache settings (from your existing config)
spring.cache.caffeine.spec=maximumSize=500,expireAfterWrite=30s
```

---

## Step 5: Create Systemd Service

```bash
sudo nano /etc/systemd/system/nusmotion.service
```

Add:
```ini
[Unit]
Description=NUS Motion Backend API
Documentation=https://github.com/your-repo/nus-motion
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=ubuntu
Group=ubuntu
WorkingDirectory=/opt/nusmotion

# Load JVM options from environment file
EnvironmentFile=/etc/nusmotion/jvm.conf

# Start the application
ExecStart=/usr/bin/java $JAVA_OPTS -jar /opt/nusmotion/app.jar \
  --spring.config.additional-location=file:/opt/nusmotion/application.properties

# Restart policy
Restart=on-failure
RestartSec=10
StartLimitBurst=3
StartLimitIntervalSec=60

# Security hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=/opt/nusmotion/logs

# Resource limits
MemoryMax=600M
MemoryHigh=550M

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=nusmotion

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable nusmotion
sudo systemctl start nusmotion
sudo systemctl status nusmotion
```

Check logs:
```bash
journalctl -u nusmotion -f
```

---

## Step 6: Install Caddy (Lightweight HTTPS Reverse Proxy)

Caddy automatically obtains and renews Let's Encrypt certificates. Uses ~20-30MB RAM.

### Ubuntu
```bash
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install caddy
```

### Oracle Linux 9
```bash
sudo dnf install -y 'dnf-command(copr)'
sudo dnf copr enable @caddy/caddy -y
sudo dnf install -y caddy
```

### Configure Caddy

```bash
sudo nano /etc/caddy/Caddyfile
```

Replace contents with:
```caddy
api.nusmotion.example.com {
    # Automatic HTTPS via Let's Encrypt
    # No manual certificate setup required

    # Reverse proxy to Spring Boot
    reverse_proxy localhost:8080

    # Logging
    log {
        output file /var/log/caddy/access.log
        format json
    }

    # Security headers
    header {
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
        Referrer-Policy strict-origin-when-cross-origin
    }

    # Health check endpoint (no logging)
    @health path /actuator/health
    handle @health {
        reverse_proxy localhost:8080
    }
}
```

**Replace `api.nusmotion.example.com` with your actual domain.**

Enable and start Caddy:
```bash
sudo mkdir -p /var/log/caddy
sudo chown caddy:caddy /var/log/caddy
sudo systemctl enable caddy
sudo systemctl start caddy
sudo systemctl status caddy
```

---

## Step 7: Oracle Cloud Security List (Firewall)

Oracle Cloud blocks all traffic by default. You must open ports in the **Security List**.

### Via Oracle Cloud Console

1. Go to **Networking** → **Virtual Cloud Networks**
2. Click your VCN → **Security Lists** → **Default Security List**
3. Click **Add Ingress Rules**

Add these rules:

| Stateless | Source CIDR | Protocol | Dest Port | Description |
|-----------|-------------|----------|-----------|-------------|
| No | 0.0.0.0/0 | TCP | 80 | HTTP (Caddy redirect) |
| No | 0.0.0.0/0 | TCP | 443 | HTTPS (Caddy) |
| No | 0.0.0.0/0 | TCP | 22 | SSH (already open) |

### VM-Level Firewall (iptables)

Oracle Linux and Ubuntu also have OS-level firewalls. Open the ports:

**Ubuntu (ufw):**
```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
sudo ufw status
```

**Oracle Linux (firewalld):**
```bash
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
sudo firewall-cmd --list-all
```

---

## Step 8: Testing

### 1. Check Spring Boot is Running
```bash
curl -s http://localhost:8080/actuator/health
# Expected: {"status":"UP"}
```

### 2. Check Caddy is Proxying
```bash
curl -s http://localhost:80
# Should redirect to HTTPS
```

### 3. Test External HTTPS
From your local machine:
```bash
curl -s https://api.nusmotion.example.com/actuator/health
# Expected: {"status":"UP"}
```

### 4. Test an API Endpoint
```bash
curl -s https://api.nusmotion.example.com/api/routes | jq
```

---

## Troubleshooting

### Spring Boot Won't Start

**Check logs:**
```bash
journalctl -u nusmotion -n 100 --no-pager
```

**Common issues:**
- **Port 8080 already in use:** `sudo lsof -i :8080`
- **Out of memory:** Reduce `-Xmx` to 350m
- **Missing config:** Ensure `/opt/nusmotion/application.properties` exists

### Caddy Certificate Errors

**Check Caddy logs:**
```bash
journalctl -u caddy -n 50 --no-pager
```

**Common issues:**
- **DNS not propagated:** Wait 30 minutes, verify with `dig +short yourdomain.com`
- **Port 80 blocked:** Caddy needs port 80 for ACME HTTP-01 challenge
- **Firewall blocking:** Check both Oracle Security List AND OS firewall

### Out of Memory (OOM)

**Check memory usage:**
```bash
free -h
ps aux --sort=-%mem | head -10
```

**If OOM killed:**
```bash
dmesg | grep -i "killed process"
```

**Solutions:**
1. Reduce heap: `-Xmx350m`
2. Add swap (1GB):
   ```bash
   sudo fallocate -l 1G /swapfile
   sudo chmod 600 /swapfile
   sudo mkswap /swapfile
   sudo swapon /swapfile
   echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
   ```

### SSL Certificate Not Working

Test certificate:
```bash
curl -vI https://api.nusmotion.example.com 2>&1 | grep -A5 "SSL certificate"
```

Force certificate renewal:
```bash
sudo caddy reload --config /etc/caddy/Caddyfile
```

---

## Memory Usage Reference

Expected memory footprint after optimization:

| Process | RSS Memory |
|---------|------------|
| Java (Spring Boot) | 350-450 MB |
| Caddy | 20-30 MB |
| OS + systemd | 200-300 MB |
| **Total** | ~700-800 MB |

This leaves ~200MB headroom for spikes.

---

## Updating the Application

```bash
# Upload new JAR to VM
scp -i ~/oracle-cloud-key.pem target/backend-0.0.1-SNAPSHOT.jar ubuntu@<VM_IP>:/home/ubuntu/

# On the VM
sudo systemctl stop nusmotion
sudo mv /home/ubuntu/backend-0.0.1-SNAPSHOT.jar /opt/nusmotion/app.jar
sudo systemctl start nusmotion
journalctl -u nusmotion -f
```

---

## Quick Reference Commands

```bash
# Service management
sudo systemctl start|stop|restart|status nusmotion
sudo systemctl start|stop|restart|status caddy

# Logs
journalctl -u nusmotion -f          # Spring Boot logs
journalctl -u caddy -f               # Caddy logs
tail -f /var/log/caddy/access.log    # Caddy access log

# Memory check
free -h
ps aux --sort=-%mem | head -5

# Ports
sudo ss -tlnp | grep -E '80|443|8080'

# Test endpoints
curl -s http://localhost:8080/actuator/health
curl -s https://api.nusmotion.example.com/actuator/health
```

---

## Security Checklist

- [ ] SSH key authentication only (disable password auth)
- [ ] Firewall restricts ingress to 22, 80, 443 only
- [ ] No secrets in application.properties (use env vars for sensitive data)
- [ ] Spring Boot running as non-root user
- [ ] Caddy auto-renews certificates (check `journalctl -u caddy`)
- [ ] Monitor memory usage (set up alerts if available)

---

## Alternative: Nginx (If Caddy Not Preferred)

If you prefer Nginx over Caddy (uses ~5-10MB RAM but requires manual cert setup):

```bash
sudo apt install -y nginx certbot python3-certbot-nginx

# Get certificate
sudo certbot --nginx -d api.nusmotion.example.com

# Nginx config is auto-generated by certbot
```

However, **Caddy is recommended** for simplicity — no manual certificate commands needed.
