# Usage [ NON DOCKER ]
- Hanya Support VPS Ubuntu 22.04 (Jammy) Dengan Kondisi VPS Baru ( Fresh VPS )
## Cara Install [ NON DOCKER ]
```bash
# Gunakan root akses
sudo su
```
```bash
# Download script GACS
git clone https://github.com/safrinnetwork/GACS-Ubuntu-22.04
```
```bash
# Masuk ke folder GACS
cd GACS-Ubuntu-22.04
```
```bash
# Beri Akses ke file-file GACS
chmod -R 777 .
```
```bash
# Install dos2unix
sudo apt-get install dos2unix
```
```bash
# Konversi format script
dos2unix GACS-Jammy.sh
```
```bash
# Install script
bash GACS-Jammy.sh
```
## Cara Install Parameter [ NON DOCKER ]

```bash
# 1. masuk ke folder parameter
cd parameter
```
```bash
# 2. Restore collections
mongorestore --db genieacs --drop /root/db
```
```bash
# 3. Restart GenieACS
systemctl start genieacs-{cwmp,ui,nbi}
```
## Penting
- Setelah Menambahkan Parameter Login Ke GenieACS > Provisions > Klik Show Pada Inform Dan Ubah Bagian const url, const AcsUser, const AcsPass, let ConnReqUser, dan const ConnReqPass
# Usage [ DOCKER ]
- Support Ubuntu Mulai Dari Ubuntu 18 Sampai Dengan Ubuntu 24
## Cara Install [ DOCKER ]
```bash
# Gunakan root akses
sudo su
```
```bash
# Update dan upgrade vps
apt update -y && apt upgrade -y && apt autoremove -y
```
```bash
# Install docker
bash <(curl -s https://raw.githubusercontent.com/safrinnetwork/Auto-Install-Docker/main/install.sh)
```
```bash
# Download script GACS
git clone https://github.com/safrinnetwork/GACS-Ubuntu-22.04
```
```bash
# Masuk ke folder GACS
cd GACS-Ubuntu-22.04
```
```bash
# Beri Akses ke file-file GACS
chmod -R 777 .
```
```bash
# Install GenieACS di docker
./install-genieacs-docker.sh
```
## Cara Install Parameter [ Docker ]

Untuk mengembalikan konfigurasi ini:

```bash
# 1. Copy files ke container
docker cp /GACS-Ubuntu-22.04/parameter/ genieacs-server:/tmp/

# 2. Restore collections
docker exec genieacs-server mongorestore --db genieacs --collection config --drop /tmp/parameter/config.bson
docker exec genieacs-server mongorestore --db genieacs --collection virtualParameters --drop /tmp/parameter/virtualParameters.bson
docker exec genieacs-server mongorestore --db genieacs --collection presets --drop /tmp/parameter/presets.bson
docker exec genieacs-server mongorestore --db genieacs --collection provisions --drop /tmp/parameter/provisions.bson

# 3. Restart GenieACS
cd /opt/genieacs-docker && docker-compose restart && sleep 15
```
## Penting
- Setelah Menambahkan Parameter Login Ke GenieACS > Provisions > Klik Show Pada Inform Dan Ubah Bagian const url, const AcsUser, const AcsPass, let ConnReqUser, dan const ConnReqPass
# Konfigurasi MikroTik
- install zerotier di mikrotik
- join network
- add firewall di mikrotik seperti berikut
```bash
/ip firewall filter add chain=forward connection-state=established,related action=accept
```
```bash
/ip firewall filter add chain=forward action=accept protocol=tcp src-address=[IP_ZEROTIER_VPS] in-interface=[NAMA_INTERFACE_ZEROTIER] out-interface=[NAMA_INTERFACE_VLAN] dst-port=58000,7547 comment="ACS -> ONU"
```
```bash
/ip firewall filter add chain=forward action=accept protocol=tcp dst-address=[IP_ZEROTIER_VPS] in-interface=[NAMA_INTERFACE_VLAN] out-interface=[NAMA_INTERFACE_VLAN] src-port=58000,7547 comment="ONU -> ACS replies"
```
```bash
/ip firewall filter add chain=forward action=accept protocol=tcp dst-address=[IP_ZEROTIER_VPS] in-interface=[NAMA_INTERFACE_VLAN] out-interface=[NAMA_INTERFACE_ZEROTIER] dst-port=7547 comment="ONU -> ACS CWMP"
```
```bash
/ip firewall filter add chain=forward in-interface=[NAMA_INTERFACE_ZEROTIER] out-interface=[NAMA_INTERFACE_VLAN] action=accept
```
- pastikan di mikrotik sudah ada vlan yang dapat terhubung dengan onu
- di onu konfigurasi tr609 dengan vlan yang sudah terkonfigurasi di mikrotik
- perhatikan port 58000 adalah contoh port request url dari onu, silahkan sesuaikan dengan port request onu masing-masing.
# Template Firewall & Zerotier
- https://nangili.id/tools/zt_firewall.html
- https://nangili.id/tools/zt_config.html
# Tutorial
- https://youtu.be/p_UNuq0rfg0 [ NON DOCKER ]
- https://youtu.be/Jt0bW3Yq2d8?feature=shared [ DOCKER ]
