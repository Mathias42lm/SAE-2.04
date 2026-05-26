#!/bin/bash
set -e

echo "[*] Création de l'arborescence des partages..."
mkdir -p /partage/{amoi,atoi,anous,public,amoi-atoi,amoi-anous}

# Ouverture des droits POSIX. Samba (smbd) gérera les restrictions 
# d'accès en fonction des directives 'valid users' et 'write list'.
chmod -R 777 /partage

echo "[*] Injection des directives de partage dans smb.conf..."
cat << 'EOF' >> /etc/samba/smb.conf

[amoi]
    path = /partage/amoi
    read only = no
    valid users = @cmoi
    write list = @cmoi

[atoi]
    path = /partage/atoi
    read only = no
    valid users = @cmoi, @ctoi
    write list = @ctoi

[anous]
    path = /partage/anous
    read only = no
    valid users = @cmoi, @ctoi, @cnous
    write list = @cnous

[public]
    path = /partage/public
    read only = no
    valid users = @cmoi, @ctoi, @cnous
    write list = @cmoi, @ctoi, @cnous

[amoi-atoi]
    path = /partage/amoi-atoi
    read only = no
    valid users = @cmoi, @ctoi
    write list = @cmoi

[amoi-anous]
    path = /partage/amoi-anous
    read only = no
    valid users = @cmoi, @cnous
    write list = @cmoi
EOF