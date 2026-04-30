docker exec -it srv-ubuntu bash

rm -f /etc/samba/smb.conf
rm -rf /var/lib/samba/private/*
rm -rf /var/lib/samba/sysvol/*

samba-tool domain provision \
  --server-role=dc \
  --use-rfc2307 \
  --dns-backend=SAMBA_INTERNAL \
  --realm=SAE.LOCAL \
  --domain=SAE \
  --adminpass="TonPassFort123!"

samba-tool group add cmoi

samba-tool user create moi "Root4242" --given-name=Moi --surname=SAE --mail-address=moi@domain.org --login-shell=/bin/bash --password=Root4242

samba-tool group addmembers cmoi moi

samba-tool user enable moi

mkdir -p /partage/amoi

sed -i 's/passwd:.*compat.*/& winbind/' /etc/nsswitch.conf
sed -i 's/group:.*compat.*/& winbind/' /etc/nsswitch.conf

# 3. Vérifier que Linux voit bien le groupe AD (la commande doit retourner cmoi)
getent group cmoi

# 4. Appliquer les droits (la commande ne renverra plus d'erreur)
chown -R root:moi /partage/amoi
chmod -R 770 /partage/amoi

cat << EOF >> /etc/samba/smb.conf

[amoi]
    path = /partage/amoi
    valid users = @cmoi
    write list = @cmoi
EOF

samba