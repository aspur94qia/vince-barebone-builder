#!/system/bin/sh
svc data enable
iptables -t mangle -A POSTROUTING -j TTL --ttl-set 64
ip6tables -t mangle -A POSTROUTING -j HL-set 64
cmd wifi set-wifi-enabled enabled
service call connectivity 33 i32 0
