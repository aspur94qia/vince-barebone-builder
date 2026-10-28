#!/bin/bash
set -e

cd work/extracted

if [ -d "sys_mnt/system/system/bin" ]; then
  SYS_BIN="sys_mnt/system/system/bin"
  SYS_ETC="sys_mnt/system/system/etc"
else
  SYS_BIN="sys_mnt/system/bin"
  SYS_ETC="sys_mnt/system/etc"
fi

echo "Detected correct bin path: $SYS_BIN"
sudo mkdir -p "$SYS_BIN" "$SYS_ETC/router" "$SYS_ETC/init" sys_mnt/system/web_ui

# Salin satu-persatu secara aman jika file ada di /tmp/native_tools/
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

echo "interface=wlan0" | sudo tee "$SYS_ETC/router/dnsmasq.conf" > /dev/null
echo "dhcp-range=192.168.4.50,192.168.4.150,12h" | sudo tee -a "$SYS_ETC/router/dnsmasq.conf" > /dev/null

echo "<html><body><h2>Vince Gateway Active</h2></body></html>" | sudo tee sys_mnt/system/web_ui/index.html > /dev/null

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
