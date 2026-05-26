#!/bin/bash
set -e

echo "[*] Création des groupes de sécurité..."
samba-tool group add cmoi
samba-tool group add ctoi
samba-tool group add cnous

echo "[*] Création des utilisateurs..."
samba-tool user create moi "Root4242" --given-name=Moi --surname=SAE --mail-address=moi@domain.org --login-shell=/bin/bash
samba-tool user create toi "Root4242" --given-name=Toi --surname=SAE --mail-address=toi@domain.org --login-shell=/bin/bash
samba-tool user create nous "Root4242" --given-name=Nous --surname=SAE --mail-address=nous@domain.org --login-shell=/bin/bash

echo "[*] Assignation des membres aux groupes..."
samba-tool group addmembers cmoi moi
samba-tool group addmembers ctoi toi
samba-tool group addmembers cnous nous