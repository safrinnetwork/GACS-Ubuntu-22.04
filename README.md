# Usage [ NON DOCKER ]
- Hanya Support VPS Ubuntu 22.04 (Jammy) Dengan Kondisi VPS Baru ( Fresh VPS )
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
chmod -R 777 .
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
- Menambahkan parameter
```
cd parameter
```
```
mongorestore --db genieacs --drop /root/db
```
```
systemctl start genieacs-{cwmp,ui,nbi}
```
- Setelah Menambahkan Parameter Login Ke GenieACS > Provisions > Klik Show Pada Inform Dan Ubah Bagian const url, const AcsUser, const AcsPass, let ConnReqUser, dan const ConnReqPass
# Usage [ DOCKER ]
- Support Ubuntu Mulai Dari Ubuntu 18 Sampai Dengan Ubuntu 24
- Pastikan Docker Sudah Terinstal
- Jika Docker Belum Terinstal Silahkan Install Dengan Command Ini
```
bash <(curl -s https://raw.githubusercontent.com/safrinnetwork/Auto-Install-Docker/main/install.sh)
```
```
git clone https://github.com/safrinnetwork/GACS-Ubuntu-22.04
```
```
cd GACS-Ubuntu-22.04
```
```
chmod -R 777 .
```
```
./install-genieacs-docker.sh
```
- Menambahkan parameter
```
docker cp /home/mostech/GACS-Ubuntu-22.04/parameter/ genieacs-server:/tmp/
```
- (UI Settings, Charts)
```
docker exec genieacs-server mongorestore \
  --db genieacs \
  --collection config \
  --drop \
  /tmp/parameter/config.bson
```

- Virtual Parameters
```
docker exec genieacs-server mongorestore \
  --db genieacs \
  --collection virtualParameters \
  --drop \
  /tmp/parameter/virtualParameters.bson
```

- Restore Presets
```
docker exec genieacs-server mongorestore \
  --db genieacs \
  --collection presets \
  --drop \
  /tmp/parameter/presets.bson
```

- Restore Provisions
```
docker exec genieacs-server mongorestore \
  --db genieacs \
  --collection provisions \
  --drop \
  /tmp/parameter/provisions.bson
```

- Restart GenieACS
```
cd /opt/genieacs-docker
docker-compose restart

# Tunggu services siap
sleep 15
```
- Setelah Menambahkan Parameter Login Ke GenieACS > Provisions > Klik Show Pada Inform Dan Ubah Bagian const url, const AcsUser, const AcsPass, let ConnReqUser, dan const ConnReqPass
# Konfigurasi MikroTik
- install zerotier di mikrotik
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

# Parameter
- Sumber parameter di ambil dari parameter publik yang sudah ada di https://github.com/beryindo/genieacs dan https://github.com/alijayanet/genieacs kemudian saya customisasi
# Tutorial [ Non Docker ]
- https://youtu.be/p_UNuq0rfg0
