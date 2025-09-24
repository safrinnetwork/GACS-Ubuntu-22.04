# GACS-Ubuntu-22.04 ( Only for fresh install vps )
This is autoinstall GenieACS For ubuntu version 22.04 (Jammy)

# Update 24-09-2025
- Support tunneling lokal via zerotier
- install zerotier di vps
- join network
- add firewall di mikrotik seperti berikut
```
/ip firewall filter add chain=forward connection-state=established,related action=accept
```
```
/ip firewall filter add chain=forward action=accept protocol=tcp src-address=[IP_ZEROTIER_VPS] in-interface=[NAMA_INTERFACE_ZEROTIER] out-interface=[NAMA_INTERFACE_VLAN] dst-port=58000,7547 comment="ACS -> ONU"
```
```
/ip firewall filter add chain=forward action=accept protocol=tcp dst-address=[IP_ZEROTIER_VPS] in-interface=[NAMA_INTERFACE_VLAN] out-interface=[NAMA_INTERFACE_VLAN] src-port=58000,7547 comment="ONU -> ACS replies"
```
```
/ip firewall filter add chain=forward action=accept protocol=tcp dst-address=[IP_ZEROTIER_VPS] in-interface=[NAMA_INTERFACE_VLAN] out-interface=[NAMA_INTERFACE_ZEROTIER] dst-port=7547 comment="ONU -> ACS CWMP"
```
```
/ip firewall filter add chain=forward in-interface=[NAMA_INTERFACE_ZEROTIER] out-interface=[NAMA_INTERFACE_VLAN] action=accept
```
- pastikan di mikrotik sudah ada vlan yang dapat terhubung dengan onu
- di onu konfigurasi tr609 dengan vlan yang sudah terkonfigurasi di mikrotik
- perhatikan port 58000 adalah contoh port request dari onu, silahkan sesuaikan dengan port request onu masing-masing.
# Docker Usage
```
chmod +x install-genieacs-docker
```
```
./install-genieacs-docker
```
# Usage
```
sudo su
```
```
git clone https://github.com/safrinnetwork/GACS-Ubuntu-22.04
```
```
cd GACS-Ubuntu-22.04
```
```
chmod +x GACS-Jammy.sh
```
```
sudo apt-get install dos2unix
```
```
dos2unix GACS-Jammy.sh
```
```
bash GACS-Jammy.sh
```

# Tutorial [ Non Docker ]
- https://youtu.be/p_UNuq0rfg0
