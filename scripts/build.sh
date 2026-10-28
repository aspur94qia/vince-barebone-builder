#!/bin/bash
set -e

mkdir -p /tmp/native_tools work/extracted output
echo "Fetching Native ARM64 Tools..."

cd /tmp/native_tools
wget -q -O busybox https://github.com/muntashirakon/busybox-NDK/releases/download/v1.36.1/busybox-arm64-v8a || true
wget -q -O hostapd https://raw.githubusercontent.com/nethunteros/android_external_hostapd/master/hostapd || true
wget -q -O dnsmasq https://raw.githubusercontent.com/eugr/dnsmasq-android/master/binary/arm64-v8a/dnsmasq || true
wget -q -O dropbear https://raw.githubusercontent.com/mchome/dropbear-android/master/bin/arm64-v8a/dropbear || true
wget -q -O iw https://raw.githubusercontent.com/nethunteros/android_external_iw/master/iw || true
wget -q -O tcpdump https://raw.githubusercontent.com/nethunteros/android_external_tcpdump/master/tcpdump || true
wget -q -O iftop https://raw.githubusercontent.com/nethunteros/android_external_iftop/master/iftop || true
chmod +x *

cd /home/runner/work/vince-barebone-builder/vince-barebone-builder
echo "Downloading LineageOS Vince..."
ROM_URL="https://github.com/imren0x/LineageOS_vince/releases/download/20260507/lineage-23.2-20260506-UNOFFICIAL-vince.zip"
aria2c -x16 -s16 -o work/rom.zip "$ROM_URL"
unzip work/rom.zip -d work/extracted/

cd work/extracted
brotli -d system.new.dat.br -o system.new.dat
wget -q https://raw.githubusercontent.com/xpirt/sdat2img/master/sdat2img.py
python3 sdat2img.py system.transfer.list system.new.dat system.img
mkdir sys_mnt
sudo mount -o loop system.img sys_mnt/

# Babat habis GUI & Bloatware
sudo rm -rf sys_mnt/system/priv-app/SystemUI 2>/dev/null || true
sudo rm -rf sys_mnt/system/priv-app/Trebuchet 2>/dev/null || true
sudo rm -rf sys_mnt/system/app/* 2>/dev/null || true
sudo rm -rf sys_mnt/system/media/audio/* 2>/dev/null || true
sudo rm -rf sys_mnt/system/fonts/* 2>/dev/null || true

SYS_TARGET="sys_mnt/system"
if [ -d "sys_mnt/system/system" ]; then
  SYS_TARGET="sys_mnt/system/system"
fi

sudo mkdir -p "$SYS_TARGET/bin" "$SYS_TARGET/etc/router" "$SYS_TARGET/web_ui" "$SYS_TARGET/etc/init"

# Copy semua tools
sudo cp /tmp/native_tools/* "$SYS_TARGET/bin/"
sudo chmod 755 "$SYS_TARGET/bin/"*
sudo "$SYS_TARGET/bin/busybox" --install -s "$SYS_TARGET/bin" 2>/dev/null || true

# Inject Config Router & Web UI
echo "interface=wlan0" | sudo tee "$SYS_TARGET/etc/router/dnsmasq.conf" > /dev/null
echo "dhcp-range=192.168.4.50,192.168.4.150,12h" | sudo tee -a "$SYS_TARGET/etc/router/dnsmasq.conf" > /dev/null

echo "<html><body><h2>Vince Gateway Active</h2></body></html>" | sudo tee "$SYS_TARGET/web_ui/index.html" > /dev/null

# Inject Script Auto Start
sudo bash -c 'cat << "INSCRIPT" > '"$SYS_TARGET"'/bin/vince_init.sh
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
sudo chmod 755 "$SYS_TARGET/bin/vince_init.sh"

sudo bash -c 'cat << "INRC" > '"$SYS_TARGET"'/etc/init/vince_gateway.rc
on property:sys.boot_completed=1
    exec u:r:init:s0 root root -- /system/bin/vince_init.sh
INRC'
sudo chmod 644 "$SYS_TARGET/etc/init/vince_gateway.rc"

# Repack
sudo umount sys_mnt/
img2simg system.img system_sparse.img
wget -q https://raw.githubusercontent.com/xpirt/img2sdat/master/img2sdat.py
python3 img2sdat.py system_sparse.img -o . -v 4
brotli -q 11 system.new.dat -o system.new.dat.br

rm -rf system.img system_sparse.img system.new.dat sys_mnt sdat2img.py img2sdat.py
zip -9 -r "../../output/vince-mini-headless.zip" boot.img vendor.new.dat.br vendor.transfer.list system.new.dat.br system.transfer.list META-INF/
