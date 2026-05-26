#!/bin/bash
set -e

echo "[*] Nettoyage des anciennes configurations..."
rm -f /etc/samba/smb.conf
rm -rf /var/lib/samba/private/*
rm -rf /var/lib/samba/sysvol/*

echo "[*] Création du domaine AD SAE.LOCAL..."
samba-tool domain provision \
  --server-role=dc \
  --use-rfc2307 \
  --dns-backend=SAMBA_INTERNAL \
  --realm=SAE.LOCAL \
  --domain=SAE \
  --adminpass="Root4242"

# Par défaut, samba-tool génère un smb.conf de base. 
# Les autres scripts viendront l'alimenter.