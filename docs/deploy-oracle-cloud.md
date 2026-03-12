# NUS Motion Backend — VPS Deployment Guide

> **Stack:** Spring Boot 4, Java 21, Caddy (auto-HTTPS reverse proxy)  
> **Tested on:** Ubuntu 24.04 LTS (works on 22.04+, Oracle Linux 9, Debian 12)

---

## Prerequisites

1. **A VPS** with at least 1GB RAM and a public IP address.
2. **SSH access** to the VPS.
3. **A deSEC account** (free) — set up in Step 6 below.

---

## Step 1: Install Java 21

```bash
sudo apt update && sudo apt install -y openjdk-21-jdk-headless
java -version   # Verify: openjdk 21.x.x
```

---

## Step 2: Build & Upload the JAR

On your **local machine**:

```bash
cd backend
./mvnw clean package -DskipTests
scp target/backend-0.0.1-SNAPSHOT.jar user@<VPS_IP>:/home/ubuntu/
```

---

## Step 3: Set Up the Application Directory

On the VPS:

```bash
sudo mkdir -p /opt/nusmotion/tomcat-tmp
sudo mv /home/ubuntu/backend-0.0.1-SNAPSHOT.jar /opt/nusmotion/app.jar
sudo chown -R ubuntu:ubuntu /opt/nusmotion
```

---

## Step 4: JVM Options (Memory Tuning)

Create a JVM config file:

```bash
sudo mkdir -p /etc/nusmotion
sudo tee /etc/nusmotion/jvm.conf > /dev/null << 'EOF'
JAVA_OPTS=-Xms256m -Xmx400m -XX:+UseSerialGC -XX:MaxMetaspaceSize=64m -XX:+ExitOnOutOfMemoryError -Djava.security.egd=file:/dev/./urandom
EOF
```

| Option | Purpose |
|--------|---------|
| `-Xms256m -Xmx400m` | Heap size (fit within 1GB RAM) |
| `-XX:+UseSerialGC` | Lowest memory GC (adds ~50ms pause, acceptable) |
| `-XX:MaxMetaspaceSize=64m` | Cap class metadata |
| `-XX:+ExitOnOutOfMemoryError` | Clean crash on OOM (systemd restarts) |

> For VPS with 2GB+ RAM, increase `-Xmx` to 800m and use `-XX:+UseG1GC` instead.

---

## Step 5: Create Systemd Service

```bash
sudo tee /etc/systemd/system/nusmotion.service > /dev/null << 'EOF'
[Unit]
Description=NUS Motion Backend API
After=network-online.target
Wants=network-online.target
StartLimitBurst=5
StartLimitIntervalSec=60

[Service]
Type=simple
User=ubuntu
Group=ubuntu
WorkingDirectory=/opt/nusmotion

EnvironmentFile=/etc/nusmotion/jvm.conf
ExecStart=/usr/bin/java $JAVA_OPTS -jar /opt/nusmotion/app.jar

Restart=on-failure
RestartSec=10

# Security hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=read-only
PrivateTmp=true
ReadWritePaths=/opt/nusmotion

# Resource limits (adjust for your VPS)
MemoryMax=600M
MemoryHigh=550M

StandardOutput=journal
StandardError=journal
SyslogIdentifier=nusmotion

[Install]
WantedBy=multi-user.target
EOF
```

**Key details:**
- `ProtectSystem=strict` makes the filesystem read-only for security.
- `PrivateTmp=true` provides a private writable `/tmp` for Tomcat.
- `ReadWritePaths=/opt/nusmotion` allows writing to the app directory (logs, tomcat-tmp).

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

## Step 6: Set Up deSEC DNS (Free Domain + HTTPS)

[deSEC](https://desec.io) provides free `dedyn.io` subdomains with automatic DNSSEC. This gives you a domain like `nusmotion.dedyn.io` that you can point to your VPS for free HTTPS.

### 1. Create an account

Go to **https://desec.io/signup** and register with your email. Confirm via the activation link sent to your inbox.

### 2. Create an API token

Log in at **https://desec.io** → **Token Management** → **Create New Token**.

Copy the token — you'll need it for the next commands. Store it safely.

### 3. Register your dedyn.io domain

```bash
# Replace YOUR_TOKEN and YOUR_SUBDOMAIN (e.g. "nusmotion")
curl -X POST https://desec.io/api/v1/domains/ \
    --header "Authorization: Token YOUR_TOKEN" \
    --header "Content-Type: application/json" \
    --data '{"name": "YOUR_SUBDOMAIN.dedyn.io"}'
```

If you get `201 Created`, your domain is registered. If `409 Conflict`, the name is taken — try a different subdomain.

### 4. Point the domain to your VPS IP

```bash
# Get your VPS public IP (run on VPS)
curl -s ifconfig.me

# Set the A record (run anywhere)
curl -X POST https://desec.io/api/v1/domains/YOUR_SUBDOMAIN.dedyn.io/rrsets/ \
    --header "Authorization: Token YOUR_TOKEN" \
    --header "Content-Type: application/json" \
    --data '{
        "subname": "",
        "type": "A",
        "ttl": 300,
        "records": ["YOUR_VPS_IP"]
    }'
```

Replace `YOUR_SUBDOMAIN`, `YOUR_TOKEN`, and `YOUR_VPS_IP` with your actual values.

### 5. Verify DNS propagation

Wait 1-2 minutes, then:

```bash
dig +short YOUR_SUBDOMAIN.dedyn.io
```

This should return your VPS IP address. If not, wait a few more minutes and try again.

> **Tip:** If you need to update the IP later (e.g. VPS migration), use `PATCH` instead of `POST`:
> ```bash
> curl -X PATCH https://desec.io/api/v1/domains/YOUR_SUBDOMAIN.dedyn.io/rrsets/@/A/ \
>     --header "Authorization: Token YOUR_TOKEN" \
>     --header "Content-Type: application/json" \
>     --data '{"records": ["NEW_VPS_IP"]}'
> ```

---

## Step 7: Install Caddy (Auto-HTTPS Reverse Proxy)

Caddy handles TLS certificates automatically via Let's Encrypt.

```bash
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install caddy
```

### Configure Caddy

```bash
sudo tee /etc/caddy/Caddyfile > /dev/null << 'EOF'
nusmotion.dedyn.io {  # Replace with your domain
    reverse_proxy localhost:8080

    header {
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
        Referrer-Policy strict-origin-when-cross-origin
    }

    log {
        output file /var/log/caddy/access.log
        format json
    }
}
EOF
```

**Replace `nusmotion.dedyn.io` with your actual deSEC domain.**

Caddy obtains TLS certificates automatically via Let's Encrypt (HTTP-01 challenge).
Ports 80 and 443 must be open for this to work.

```bash
sudo mkdir -p /var/log/caddy
sudo chown caddy:caddy /var/log/caddy
sudo systemctl enable caddy
sudo systemctl start caddy
```

---

## Step 8: Open Firewall Ports

### OS-Level Firewall (iptables)

Oracle Cloud Ubuntu images use raw iptables rules (not ufw). Add rules for HTTP and HTTPS **before** the default REJECT rule:

```bash
# Find the REJECT rule position
sudo iptables -L INPUT -n --line-numbers | grep REJECT
# Note the line number (typically 5)

# Insert BEFORE the REJECT rule (replace 5 with your REJECT line number)
sudo iptables -I INPUT 5 -m state --state NEW -p tcp --dport 443 -j ACCEPT
sudo iptables -I INPUT 5 -m state --state NEW -p tcp --dport 80 -j ACCEPT
sudo netfilter-persistent save
```

> **Critical:** Rules must be inserted **before** the REJECT line. If they end up after it, all traffic is rejected before reaching your ACCEPT rules.

Verify the order (80 and 443 should appear before REJECT):
```bash
sudo iptables -L INPUT -n --line-numbers
```

> **Note:** If `netfilter-persistent` is not installed: `sudo apt install -y iptables-persistent`

### Oracle Cloud Security List (required)

Oracle Cloud also blocks traffic at the VCN level. Open ports in the **Security List** via the web console:

1. **Networking** → **Virtual Cloud Networks** → your VCN
2. **Subnets** → your subnet → **Security Lists** → **Default Security List**
3. **Add Ingress Rules:**

| Source CIDR | Protocol | Dest Port | Description |
|-------------|----------|-----------|-------------|
| 0.0.0.0/0 | TCP | 80 | HTTP (Caddy→HTTPS redirect) |
| 0.0.0.0/0 | TCP | 443 | HTTPS (Caddy TLS) |

Port 22 (SSH) should already be open by default.

### Non-Oracle VPS (Hetzner, DigitalOcean, etc.)

If your VPS uses ufw:
```bash
sudo apt install -y ufw
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

---

## Step 9: Verify

### 1. Spring Boot (local on VPS)
```bash
# Bus stops
curl -s http://localhost:8080/api/stops | head -c 200

# Bus routes/shuttles
curl -s http://localhost:8080/api/shuttles | head -c 200

# Active buses
curl -s http://localhost:8080/api/active-buses | head -c 200

# Weather (NUS coordinates)
curl -s 'http://localhost:8080/api/weather?lat=1.2966&lng=103.7764'

# Route planning
curl -s 'http://localhost:8080/api/route?from=COM3&to=University+Hall' | head -c 500

# Buildings
curl -s http://localhost:8080/api/buildings | head -c 200
```

### 2. External HTTPS (from your local machine)
```bash
curl -s https://nusmotion.dedyn.io/api/stops | head -c 200
curl -s 'https://nusmotion.dedyn.io/api/weather?lat=1.2966&lng=103.7764'
```

---

## Updating the Application

```bash
# Upload new JAR
scp target/backend-0.0.1-SNAPSHOT.jar user@<VPS_IP>:/home/ubuntu/

# On VPS
sudo systemctl stop nusmotion
sudo mv /home/ubuntu/backend-0.0.1-SNAPSHOT.jar /opt/nusmotion/app.jar
sudo systemctl start nusmotion
journalctl -u nusmotion -f
```

---

## Troubleshooting

### Service won't start
```bash
journalctl -u nusmotion -n 100 --no-pager
```
- **Port 8080 in use:** `sudo lsof -i :8080` then `sudo kill <PID>`
- **Read-only /tmp:** Verify `PrivateTmp=true` is in the service file and run `sudo systemctl daemon-reload && sudo systemctl restart nusmotion`
- **Out of memory:** Reduce `-Xmx` to 350m in `/etc/nusmotion/jvm.conf`

### Caddy not working
```bash
journalctl -u caddy -n 50 --no-pager
```
- **DNS not propagated:** Wait 30 min, check with `dig +short yourdomain.com`
- **Port 80 blocked:** Caddy needs port 80 for Let's Encrypt ACME challenge
- **TLS internal error / no cert:** Ports 80+443 must be open. Check `sudo iptables -L INPUT -n --line-numbers` — if the ACCEPT rules for 80/443 are **after** the REJECT rule, they're being ignored. Move them before the REJECT.
- **"server is listening only on the HTTP port":** The Caddyfile wasn't loaded. Run `sudo systemctl reload caddy` and check logs.

### OOM kills
```bash
dmesg | grep -i "killed process"
free -h
```
Add swap if needed:
```bash
sudo fallocate -l 1G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

---

## Quick Reference

```bash
# Service
sudo systemctl start|stop|restart|status nusmotion
sudo systemctl start|stop|restart|status caddy

# Logs
journalctl -u nusmotion -f
journalctl -u caddy -f

# Memory
free -h
ps aux --sort=-%mem | head -5

# Ports
sudo ss -tlnp | grep -E '80|443|8080'
```
