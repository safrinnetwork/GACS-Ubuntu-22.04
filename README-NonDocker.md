# GACS — Non‑Docker Install (Ubuntu 22.04 Jammy)

![Ubuntu 22.04](https://img.shields.io/badge/Ubuntu-22.04%20Jammy-E95420?logo=ubuntu&logoColor=white)

> **Hanya Untuk** VPS **baru/fresh** dengan OS **Ubuntu 22.04 (Jammy)**.

---

## Catatan
Panduan ini menginstal **GenieACS** langsung di host beserta virtual parameter dari repo yang sudah tersedia.

---

## Prasyarat
- Akses **root** ke VPS
- Jika di VPS ada firewall pastikan port yang terbuka : **7547/TCP (CWMP), 7557/TCP (NBI), 3000/TCP (UI)**

---

## Instalasi
```bash
# 1) Masuk sebagai root
sudo su
```
```bash
# 2) Download Script GACS
git clone https://github.com/safrinnetwork/GACS-Ubuntu-22.04
```
```bash
# 3) Masuk ke folder GACS
cd GACS-Ubuntu-22.04
```
```bash
# 4) Install dos2unix
apt-get update -y && apt-get install -y dos2unix
```
```bash
# 5) Convert format script GACS
dos2unix GACS-Jammy.sh
```
```bash
# 6) Beri izin script GACS
chmod +x GACS-Jammy.sh
```
```bash
# 7) Instal GACS
./GACS-Jammy.sh
```

---

## Install Parameter
```bash
# 1) Masuk ke folder parameter di repo
cd parameter
```
```
# 2) Install parameter
mongorestore --db genieacs --drop .
```
```
# 3) Restart service GenieACS
systemctl restart genieacs-{cwmp,ui,nbi}
```
> Jika dump Anda berada di lokasi lain, sesuaikan path pada langkah nomor (2).

---

## Penting (Provisions → Inform)
Setelah **menambahkan parameter login**, buka **GenieACS UI → Provisions → Show (Inform)** dan perbarui:
- `const url`
- `const AcsUser`
- `const AcsPass`
- `let ConnReqUser`
- `const ConnReqPass`

Simpan perubahan agar **Inform/Connection Request** sesuai dengan kredensial dan alamat ACS Anda.

---
## Konfigurasi Zerotier VPS
```bash
# Install Zerotier
curl -s https://install.zerotier.com | sudo bash
```
```bash
# Join Network
zerotier-cli join [Network id]
```
> **Contoh:** [Network id] diganti dengan network yang sesuai dengan network id pada akun zerotier.
> ```bash
> zerotier-cli join abcd1234
> ```

---
## Konfigurasi Zerotier MikroTik (TR‑069 via ZeroTier)
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
- **Non‑Docker** https://youtu.be/p_UNuq0rfg0

