#!/bin/bash

echo "First fill in the 'ssid' and 'wpa_passphrase' fields in the hostapd config below, then remove this message"
exit 1

apt-get install -y hostapd dnsmasq wireless-tools iw wvdial

# tell dhcpcd that wlan0 has a static ip
grep -q -F "interface wlan0" /etc/dhcpcd.conf || echo "interface wlan0  
   static ip_address=10.0.0.1/24" >> /etc/dhcpcd.conf

# stop wpa supplicant from interfering with wlan interface
sed -i 's\[^#]wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf\#wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf\' /etc/network/interfaces

# Setup dnsmasq config
cat <<EOF > /etc/dnsmasq.conf
interface=wlan0
bind-interfaces
server=8.8.8.8
domain-needed
bogus-priv
dhcp-range=10.0.0.10,10.0.0.250,12h
dhcp-option=3,10.0.0.1
dhcp-option=6,10.0.0.1
#log-queries
#log-facility=/var/log/dnsmasq.log
EOF

ifconfig wlan0 up
ifconfig wlan0 10.0.0.1/24

# forward to tunnel interface created by openvpn
iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE  
iptables -A FORWARD -i tun0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT  
iptables -A FORWARD -i wlan0 -o tun0 -j ACCEPT 

# enable packet fowarding
sed -i 's/#net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf
echo '1' > /proc/sys/net/ipv4/ip_forward

# Setup the hostapd config
sed -i 's#^DAEMON_CONF=.*#DAEMON_CONF=/etc/hostapd/hostapd.conf#' /etc/init.d/hostapd
cat <<EOF > /etc/hostapd/hostapd.conf
interface=wlan0
driver=nl80211
channel=1
country_code=ES
hw_mode=g
macaddr_acl=0

ssid=
wpa_passphrase=
wpa=2
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP

# Change the broadcasted/multicasted keys after this many seconds.
wpa_group_rekey=600
# Change the master key after this many seconds. Master key is used as a basis
wpa_gmk_rekey=86400

EOF


service dhcpcd restart
service dnsmasq restart
service hostapd start
