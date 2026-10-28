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
mkdir -p "$SYS_BIN" "$SYS_ETC/router" "$SYS_ETC/init" sys_mnt/system/web_ui

cp /tmp/native_tools/busybox "$SYS_BIN/" || true
cp /tmp/native_tools/hostapd "$SYS_BIN/" || true
cp /tmp/native_tools/dnsmasq "$SYS_BIN/" || true
cp /tmp/native_tools/dropbear "$SYS_BIN/" || true
cp /tmp/native_tools/iw "$SYS_BIN/" || true
cp /tmp/native_tools/tcpdump "$SYS_BIN/" || true
cp /tmp/native_tools/iftop "$SYS_BIN/" || true

chmod 755 "$SYS_BIN/"*
"$SYS_BIN/busybox" --install -s "$SYS_BIN" 2>/dev/null || true

echo "interface=wlan0" > "$SYS_ETC/router/dnsmasq.conf"
echo "dhcp-range=192.168.4.50,192.168.4.150,12h" >> "$SYS_ETC/router/dnsmasq.conf"

echo "<html><body><h2>Vince Gateway Active</h2></body></html>" > sys_mnt/system/web_ui/index.html

cat << 'INSCRIPT' > "$SYS_BIN/vince_init.sh"
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
INSCRIPT

chmod 755 "$SYS_BIN/vince_init.sh"

cat << 'INRC' > "$SYS_ETC/init/vince_gateway.rc"
on property:sys.boot_completed=1
    exec u:r:init:s0 root root -- /system/bin/vince_init.sh
INRC

chmod 644 "$SYS_ETC/init/vince_gateway.rc"
