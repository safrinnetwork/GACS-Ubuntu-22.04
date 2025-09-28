# GenieACS Configuration Backup

## Cara Restore

Untuk mengembalikan konfigurasi ini:

```bash
# 1. Copy files ke container
docker cp /home/mostech/GACS-Ubuntu-22.04/parameter/ genieacs-server:/tmp/

# 2. Restore collections
docker exec genieacs-server mongorestore --db genieacs --collection config --drop /tmp/parameter/config.bson
docker exec genieacs-server mongorestore --db genieacs --collection virtualParameters --drop /tmp/parameter/virtualParameters.bson
docker exec genieacs-server mongorestore --db genieacs --collection presets --drop /tmp/parameter/presets.bson
docker exec genieacs-server mongorestore --db genieacs --collection provisions --drop /tmp/parameter/provisions.bson

# 3. Restart GenieACS
cd /opt/genieacs-docker && docker-compose restart && sleep 15
```

## Catatan Penting

- Backup ini mengandung **SEMUA** customization UI yang telah dilakukan
- Pastikan GenieACS version yang sama (1.2.13) untuk kompatibilitas
- Backup ini **TIDAK** mengandung data device, hanya konfigurasi UI dan parameter
- File .metadata.json berisi informasi tambahan untuk MongoDB import/export
