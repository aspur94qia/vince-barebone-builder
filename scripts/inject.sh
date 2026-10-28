#!/bin/bash
set -ex

cd work/extracted

echo "==> 1. EXTREME SYSTEM CORE STRIPPING..."
sudo rm -rf sys_mnt/system/app/* 2>/dev/null || true
sudo rm -rf sys_mnt/system/priv-app/* 2>/dev/null || true
sudo rm -rf sys_mnt/system/apex/* 2>/dev/null || true
sudo rm -rf sys_mnt/system/product/* 2>/dev/null || true
sudo rm -rf sys_mnt/system/system_ext/* 2>/dev/null || true
sudo rm -rf sys_mnt/system/wallpaper/* 2>/dev/null || true
sudo rm -rf sys_mnt/system/fonts/* 2>/dev/null || true
sudo rm -rf sys_mnt/system/media/* 2>/dev/null || true
sudo rm -rf sys_mnt/system/tts/* 2>/dev/null || true

# 2. VENDOR DEEP EXTRACTION & TRIMMING (Wajib Ada & Di-repack)
if [ -f "vendor.new.dat.br" ]; then
  echo "==> 2. Unpacking and trimming vendor partition..."
  brotli -d vendor.new.dat.br -o vendor.new.dat
  python3 sdat2img.py vendor.transfer.list vendor.new.dat vendor.img
  mkdir -p vendor_mnt
  sudo mount -o loop vendor.img vendor_mnt/
  
  # Bersihkan bloatware vendor tapi amankan driver/firmware inti
  sudo rm -rf vendor_mnt/app/* 2>/dev/null || true
  sudo rm -rf vendor_mnt/priv-app/* 2>/dev/null || true
  sudo rm -rf vendor_mnt/overlay/* 2>/dev/null || true
  sudo rm -rf vendor_mnt/media/* 2>/dev/null || true
  
  sudo umount vendor_mnt || true
  ls -lh vendor.img
fi

# 3. Injeksi Network Tools Prioritas
if [ -d "sys_mnt/system/system/bin" ]; then
  SYS_BIN="sys_mnt/system/system/bin"
  SYS_ETC="sys_mnt/system/system/etc"
else
  SYS_BIN="sys_mnt/system/bin"
  SYS_ETC="sys_mnt/system/etc"
fi

sudo mkdir -p "$SYS_BIN" "$SYS_ETC/router" "$SYS_ETC/init" sys_mnt/system/web_ui

for tool in busybox hostapd dnsmasq dropbear iw tcpdump iftop; do
  if [ -f "/tmp/native_tools/$tool" ]; then
    sudo cp "/tmp/native_tools/$tool" "$SYS_BIN/"
    sudo chmod 755 "$SYS_BIN/$tool"
  fi
done

sudo "$SYS_BIN/busybox" --install -s "$SYS_BIN" 2>/dev/null || true

# Konfigurasi & Init Script
echo "interface=wlan0" | sudo tee "$SYS_ETC/router/dnsmasq.conf" > /dev/null
echo "dhcp-range=192.168.4.50,192.168.4.150,12h" | sudo tee -a "$SYS_ETC/router/dnsmasq.conf" > /dev/null
echo "<html><body><h2>Vince Core Router Active</h2></body></html>" | sudo tee sys_mnt/system/web_ui/index.html > /dev/null

sudo bash -c 'cat << "INSCRIPT" > '"$SYS_BIN"'/vince_init.sh
#!/system/bin/sh
sleep 8
setenforce 0 2>/dev/null || true
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -t nat -A POSTROUTING -o rmnet_data0 -j MASQUERADE 2>/dev/null || true
iptables -t mangle -A POSTROUTING -j TTL --ttl-set 64 2>/dev/null || true
svc wifi enable 2>/dev/null || true
cmd wifi start-softap Vince_Core_AP open 2>/dev/null || true
svc bluetooth enable 2>/dev/null || true
bluetoothctl power on 2>/dev/null || true
dropbear -R -p 22 2>/dev/null || true
INSCRIPT'

sudo chmod 755 "$SYS_BIN/vince_init.sh"

sudo bash -c 'cat << "INRC" > '"$SYS_ETC"'/init/vince_gateway.rc
on property:sys.boot_completed=1
    exec u:r:init:s0 root root -- /system/bin/vince_init.sh
INRC'

sudo chmod 644 "$SYS_ETC/init/vince_gateway.rc"
