# GenieACS Configuration Backup

Backup ini dibuat pada: **28 September 2025 - 10:05:18**

## Isi Backup

Folder ini berisi backup lengkap dari konfigurasi GenieACS dengan semua customization yang telah diterapkan:

### 1. config.bson & config.metadata.json
- **UI Configuration**: Semua konfigurasi tampilan (overview charts, device list, dll)
- **Chart Colors**: Warna custom untuk Status, PON, Device charts
- **Chart Labels**: Label yang sudah dimodifikasi (Overview, Ethernet, Today, dll)
- **Temperature Indicators**: Konfigurasi indikator visual untuk temperature
- **Filter Configurations**: Pengaturan filter dan search
- **3,893 documents** - Konfigurasi UI terlengkap

### 2. virtualParameters.bson & virtualParameters.metadata.json
- **Virtual Parameters**: Parameter khusus seperti gettemp, RXPower, pppoeIP, dll
- **Custom Functions**: Function untuk mengambil data dari device
- **19 documents** - Parameter virtual yang sudah dikustomisasi

### 3. presets.bson & presets.metadata.json
- **Device Presets**: Template konfigurasi untuk berbagai jenis device
- **3 documents** - Preset standar

### 4. provisions.bson & provisions.metadata.json
- **Provisioning Scripts**: Script untuk auto-konfigurasi device
- **Device Templates**: Template untuk berbagai manufacturer
- **3 documents** - Provision scripts

## Fitur Customization yang Tersimpan

### UI Customizations:
- ✅ Overview page title: "Overview" (dari "ACS-TR069 || Config & Monitoring")
- ✅ Chart PON: "Ethernet" (dari "Ethernet/Converter")
- ✅ Chart Registered: "Today" (dari "Register Hari Ini")
- ✅ Device chart: Kategori "Xpon" untuk manufacturer ZICG
- ✅ Temperature indicators: Lingkaran warna tanpa threshold text

### Chart Colors:
- ✅ **Status Chart**: Online (#4668e3), Offline ranges (#e34b46 → #2b0e0d)
- ✅ **PON Chart**: GPON (#29c7cc), EPON (#cc2998), Ethernet (#4f5454)
- ✅ **Device Chart**: Huawei (#6484de), FiberHome (#61cc49), Xpon (#d9cf1e), dll

### Temperature Configuration:
- ✅ **Visual Indicators**: Lingkaran warna berdasarkan suhu
- ✅ **Labels**: Normal, Hangat, Panas, Warning (tanpa threshold text)
- ✅ **Colors**: Blue (#00DBFF), Yellow (#fffa00), Red (#FF2400)

## Cara Restore

Untuk mengembalikan konfigurasi ini:

```bash
# 1. Copy files ke container
docker cp /home/mostech/GACS-Ubuntu-22.04/newparameter/ genieacs-server:/tmp/

# 2. Restore collections
docker exec genieacs-server mongorestore --db genieacs --collection config --drop /tmp/newparameter/config.bson
docker exec genieacs-server mongorestore --db genieacs --collection virtualParameters --drop /tmp/newparameter/virtualParameters.bson
docker exec genieacs-server mongorestore --db genieacs --collection presets --drop /tmp/newparameter/presets.bson
docker exec genieacs-server mongorestore --db genieacs --collection provisions --drop /tmp/newparameter/provisions.bson

# 3. Restart GenieACS
cd /opt/genieacs-docker && docker-compose restart && sleep 15
```

## Catatan Penting

- Backup ini mengandung **SEMUA** customization UI yang telah dilakukan
- Pastikan GenieACS version yang sama (1.2.13) untuk kompatibilitas
- Backup ini **TIDAK** mengandung data device, hanya konfigurasi UI dan parameter
- File .metadata.json berisi informasi tambahan untuk MongoDB import/export