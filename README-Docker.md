# GACS — Docker Install (Ubuntu 18–24)

![Ubuntu](https://img.shields.io/badge/Ubuntu-18.04%20%E2%80%93%2024.04-E95420?logo=ubuntu&logoColor=white) ![Docker](https://img.shields.io/badge/Docker-Engine%20%2B%20Compose-2496ED?logo=docker&logoColor=white)

> **Untuk** Ubuntu **18.04 hingga 24.04** dengan **Docker** & **Docker Compose**.

---

## Catatan
Panduan ini menginstal **GenieACS** menggunakan Docker/Compose beserta virtual parameter dari repo yang sudah tersedia.

---

## Prasyarat
- Akses **root** ke VPS
- Jika di VPS ada firewall pastikan port yang terbuka : **7547/TCP, 7557/TCP, 3000/TCP**

---

## Instalasi GenieACS Docker + Zerotier ( VPS )
```bash
# 1) Masuk sebagai root
sudo su
```
```bash
# 2) Update singkat
apt update -y && apt upgrade -y && apt autoremove -y
```
```bash
# 3) Pasang Docker + Compose (script otomatis)
bash <(curl -s https://raw.githubusercontent.com/safrinnetwork/Auto-Install-Docker/main/install.sh)
```
```bash
# 4) Download Script GACS
git clone https://github.com/safrinnetwork/GACS-Ubuntu-22.04
```
```bash
# 5) Masuk ke folder GACS
cd GACS-Ubuntu-22.04
```
```bash
# 6) Jalankan installer Docker
chmod +x install-genieacs-docker.sh
./install-genieacs-docker.sh
```

---

## Instalasi GenieACS Docker ( Mini PC )
```bash
# 1) Masuk sebagai root
sudo su
```
```bash
# 2) Update singkat
apt update -y && apt upgrade -y && apt autoremove -y
```
```bash
# 3) Pasang Docker + Compose (script otomatis)
bash <(curl -s https://raw.githubusercontent.com/safrinnetwork/Auto-Install-Docker/main/install.sh)
```
```bash
# 4) Download Script GACS
git clone https://github.com/safrinnetwork/GACS-Ubuntu-22.04
```
```bash
# 5) Masuk ke folder GACS
cd GACS-Ubuntu-22.04
```
```bash
# 6) Jalankan installer Docker
chmod +x docker-non-zerotier.sh
./docker-non-zerotier.sh
```

---

## Install Virtual Parameter (Docker)
Untuk Instal Parameter `config`, `virtualParameters`, `presets`, dan `provisions`:

```bash
# 1) Salin folder parameter ke container
#   (dari direktori repo GACS)
docker cp ./parameter/ genieacs-server:/tmp/
```
```bash
# 2) Restore parameter ke database 'genieacs'
docker exec genieacs-server mongorestore --db genieacs --collection config              --drop /tmp/parameter/config.bson
docker exec genieacs-server mongorestore --db genieacs --collection virtualParameters   --drop /tmp/parameter/virtualParameters.bson
docker exec genieacs-server mongorestore --db genieacs --collection presets             --drop /tmp/parameter/presets.bson
docker exec genieacs-server mongorestore --db genieacs --collection provisions          --drop /tmp/parameter/provisions.bson
```
```bash
# 3) Restart layanan (Compose)
cd /opt/genieacs-docker && docker-compose restart && sleep 15
```

## Penting (Provisions → Inform)
Setelah **menambahkan parameter login**, buka **GenieACS UI → Provisions → Show (Inform)** dan perbarui:
- `const url`
- `const AcsUser`
- `const AcsPass`
- `let ConnReqUser`
- `const ConnReqPass`

---

## Konfigurasi MikroTik (TR‑069 via ZeroTier)
1. **Install & join** ZeroTier di MikroTik.
2. Pastikan ada **VLAN** yang terhubung ke **ONU**.
3. Contoh rule firewall (sesuaikan `IP_ZEROTIER_VPS`, nama interface, dan port request ONU — contoh **58000**):

```bash
/ip firewall filter add chain=forward connection-state=established,related action=accept
/ip firewall filter add chain=forward action=accept protocol=tcp src-address=[IP_ZEROTIER_VPS] \
  in-interface=[NAMA_INTERFACE_ZEROTIER] out-interface=[NAMA_INTERFACE_VLAN] dst-port=58000,7547 comment="ACS -> ONU"
/ip firewall filter add chain=forward action=accept protocol=tcp dst-address=[IP_ZEROTIER_VPS] \
  in-interface=[NAMA_INTERFACE_VLAN] out-interface=[NAMA_INTERFACE_VLAN] src-port=58000,7547 comment="ONU -> ACS replies"
/ip firewall filter add chain=forward action=accept protocol=tcp dst-address=[IP_ZEROTIER_VPS] \
  in-interface=[NAMA_INTERFACE_VLAN] out-interface=[NAMA_INTERFACE_ZEROTIER] dst-port=7547 comment="ONU -> ACS CWMP"
/ip firewall filter add chain=forward in-interface=[NAMA_INTERFACE_ZEROTIER] out-interface=[NAMA_INTERFACE_VLAN] action=accept
```
> **Catatan:** Port **58000** adalah contoh Connection Request URL dari ONU — silakan sesuaikan dengan perangkat Anda.

---

## Templat Otomatis
- ZeroTier Firewall Helper https://nangili.id/tools/zt_firewall.html
- ZeroTier Config Helper https://nangili.id/tools/zt_config.html

---

## Video Panduan
- **Docker** https://youtu.be/Jt0bW3Yq2d8?feature=shared

