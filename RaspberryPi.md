##Raspberry Pi Installing

1. Raspberry pi AP network management software and automatic iptables management software
```sh
sudo apt-get -y install hostapd dnsmasq

sudo DEBIAN_FRONTEND=noninteractive apt install -y netfilter-persistent iptables-persistent
```
2. Configure AP Gateway as Static IP
```sh
sudo nano /etc/dhcpcd.conf

interface wlan0
    static ip_address=192.168.10.1/24
    nohook wpa_supplicant
```
3. Enable hostapd and dnsmasq
```sh
sudo systemctl unmask hostapd.service
sudo systemctl enable hostapd.service
sudo systemctl enable dnsmasq.service
```
4. hostapd Settings
```sh
sudo nano /etc/hostapd/hostapd.conf

country_code=GB
interface=wlan0
ssid=SmartGlasses
hw_mode=g
channel=7
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=raspberrypi
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
```
5. dnsmasq Settings
```sh
sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
sudo nano /etc/dnsmasq.conf

interface=wlan0 # Listening interface
dhcp-range=192.168.10.2,192.168.10.200,255.255.255.0,24h
                # Pool of IP addresses served via DHCP
domain=wlan     # Local wireless DNS domain
address=/gw.wlan/192.168.10.1
                # Alias for this router
```
6. enable routing iptables Setting
```sh
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo netfilter-persistent save

sudo nano /etc/sysctl.conf
#net.ipv4.ip_forward=1 -> net.ipv4.ip_forward=1
```
7. Reboot
```sh
sudo init 6
```
