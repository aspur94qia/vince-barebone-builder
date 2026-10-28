#!/bin/bash
set -e

cd work/extracted

echo "==> Unpacking vendor image for deep cleaning..."
if [ -f "vendor.new.dat.br" ]; then
  brotli -d vendor.new.dat.br -o vendor.new.dat
  python3 sdat2img.py vendor.transfer.list vendor.new.dat vendor.img 2>/dev/null || true
  mkdir -p vendor_mnt
  sudo mount -o loop vendor.img vendor_mnt/
  
  echo "==> Cleaning vendor bloatware (keeping drivers & HAL)..."
  sudo rm -rf vendor_mnt/app/* 2>/dev/null || true
  sudo rm -rf vendor_mnt/priv-app/* 2>/dev/null || true
  sudo rm -rf vendor_mnt/media/* 2>/dev/null || true
  
  sudo umount vendor_mnt/
  img2simg vendor.img vendor_sparse.img
  rm -f vendor.new.dat.br vendor.transfer.list vendor.new.dat vendor.img
  python3 img2sdat.py vendor_sparse.img -o . -v 4 2>/dev/null || true
  brotli -q 6 vendor.new.dat -o vendor.new.dat.br 2>/dev/null || true
  rm -f vendor_sparse.img vendor.new.dat
fi

# Deteksi path system bin
if [ -d "sys_mnt/system/system/bin" ]; then
  SYS_BIN="sys_mnt/system/system/bin"
  SYS_ETC="sys_mnt/system/system/etc"
else
  SYS_BIN="sys_mnt/system/bin"
  SYS_ETC="sys_mnt/system/etc"
fi

echo "Detected correct bin path: $SYS_BIN"
sudo mkdir -p "$SYS_BIN" "$SYS_ETC/router" "$SYS_ETC/init" sys_mnt/system/web_ui

# Injeksi tools prioritas network gateway
for tool in busybox hostapd dnsmasq dropbear iw tcpdump iftop; do
  if [ -f "/tmp/native_tools/$tool" ]; then
    sudo cp "/tmp/native_tools/$tool" "$SYS_BIN/"
    sudo chmod 755 "$SYS_BIN/$tool"
    echo "Successfully injected: $tool"
  else
    echo "Warning: /tmp/native_tools/$tool not found!"
  fi
done

sudo "$SYS_BIN/busybox" --install -s "$SYS_BIN" 2>/dev/null || true

# Konfigurasi Network & Web UI
echo "interface=wlan0" | sudo tee "$SYS_ETC/router/dnsmasq.conf" > /dev/null
echo "dhcp-range=192.168.4.50,192.168.4.150,12h" | sudo tee -a "$SYS_ETC/router/dnsmasq.conf" > /dev/null
echo "<html><body><h2>Vince Gateway Active</h2></body></html>" | sudo tee sys_mnt/system/web_ui/index.html > /dev/null

# Skrip init otomatis (TTL 64, IP Forward, Hostapd/SoftAP, Dropbear SSH)
sudo bash -c 'cat << "INSCRIPT" > '"$SYS_BIN"'/vince_init.sh
#!/system/bin/sh
sleep 8
setenforce 0 2>/dev/null || true
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -t nat -A POSTROUTING -o rmnet_data0 -j MASQUERADE 2>/dev/null || true
iptables -t mangle -A POSTROUTING -j TTL --ttl-set 64 2>/dev/null || true
svc wifi enable 2>/dev/null || true
cmd wifi start-softap Vince_Beast_AP open 2>/dev/null || true
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
