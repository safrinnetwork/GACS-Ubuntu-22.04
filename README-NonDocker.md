# GACS — Non‑Docker Install (Ubuntu 22.04 Jammy)

![Ubuntu 22.04](https://img.shields.io/badge/Ubuntu-22.04%20Jammy-E95420?logo=ubuntu&logoColor=white)

> **Dukungan:** VPS **baru/fresh** yang menjalankan **Ubuntu 22.04 (Jammy)**.

---

## Ringkas
Panduan ini memasang **GenieACS** langsung di host (tanpa Docker) dan mengembalikan koleksi parameter bawaan dari repo.

---

## Prasyarat
- Akses **root** ke VPS
- Port yang dibutuhkan terbuka: **7547/TCP (CWMP), 7557/TCP (NBI), 3000/TCP (UI)**

---

## Instalasi
```bash
# 1) Masuk sebagai root
sudo -i

# 2) Ambil repo GACS
git clone https://github.com/safrinnetwork/GACS-Ubuntu-22.04
cd GACS-Ubuntu-22.04

# 3) Pastikan utilitas dos2unix ada
apt-get update -y && apt-get install -y dos2unix

# 4) Konversi dan beri izin eksekusi installer
dos2unix GACS-Jammy.sh
chmod +x GACS-Jammy.sh

# 5) Jalankan installer
./GACS-Jammy.sh
```

---

## Restore Parameter (Non‑Docker)
```bash
# 1) Masuk ke folder parameter di repo
cd ~/GACS-Ubuntu-22.04/parameter

# 2) Kembalikan dump (semua koleksi)
mongorestore --db genieacs --drop .

# 3) Restart layanan GenieACS
systemctl restart genieacs-{cwmp,ui,nbi}
```
> Jika dump Anda berada di lokasi lain, sesuaikan path pada langkah (2).

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

## Templat Bantu
- ZeroTier Firewall Helper: https://nangili.id/tools/zt_firewall.html
- ZeroTier Config Helper: https://nangili.id/tools/zt_config.html

---

## Video Panduan
- **Non‑Docker:** https://youtu.be/p_UNuq0rfg0

