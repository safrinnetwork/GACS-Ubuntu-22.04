# GenieACS Fixed Configuration Backup

Backup konfigurasi GenieACS yang telah dikustomisasi dengan perubahan berikut:

## Perubahan Chart Overview
- **Status**: on/off → Online/Offline (warna online: hijau)
- **PON**: Access Type → PON  
- **Device**: Merk Perangkat → Device
- **Registered**: Devices Register → Registered
- **Temperature**: Optical Temperatur → Temperature

## Perubahan RX Power
- **Labels**: Bagus→Baik, Lumayan→Normal, Kritis→Buruk
- **Range**: 
  - Baik: < -20.0 dBm (Biru)
  - Normal: -20.0 sampai -23.0 dBm (Kuning)  
  - Buruk: > -23.0 dBm (Merah)

## Perubahan Temperature
- **Labels**: Adem→Normal, Anget→Hangat, Puanass→Panas, Awas!!!→Warning

## Cara Restore
```bash
# Stop GenieACS
genieacs stop

# Restore database
mongorestore --db=genieacs --drop /path/to/fix_config/

# Start GenieACS  
genieacs start
```

## File Contents
- config.bson: UI configuration (3886 records)
- presets.bson: Device presets (3 records)
- provisions.bson: Provisioning scripts (3 records)
- virtualParameters.bson: Virtual parameters (19 records)

Backup dibuat pada: $(date)
