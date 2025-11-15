# GenieACS Parameter Configuration

## Cara Install Parameter

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

## Sumber Parameter

- https://github.com/alijayanet/genieacs
- github.com/beryindo/genieacs
- R-Tech
