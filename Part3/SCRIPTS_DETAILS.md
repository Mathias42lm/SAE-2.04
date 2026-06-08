# Documentation Détaillée des Scripts - Part3 Samba4 AD

## Vue d'ensemble

Ce document explique le fonctionnement interne de tous les scripts PowerShell (.ps1) et Bash (.sh) du projet Part3.

---

## 1. w-start.ps1 (Windows Entry Point)

### Objectif
Orchestrer le déploiement complet de l'infrastructure Docker depuis Windows.

### Flux d'exécution
1. Configuration PowerShell (erreur stricte)
2. Nettoyage Docker (docker compose down -v)
3. Reconstruction et démarrage (docker compose up -d --build)
4. Attente de stabilisation (5 secondes)
5. Vérification du statut du conteneur

### Variables clés
- \\Continue = 'Stop'\ : Force arrêt sur erreur
- \\ = "srv-ubuntu"\ : Nom du conteneur Docker
- \\\ : Booléen indiquant si le conteneur est actif

### Code clé
\\\powershell
docker compose down -v          # Nettoie complètement (volumes aussi)
docker compose up -d --build    # Reconstruit l'image et démarre
Start-Sleep -Seconds 5          # Attente pour stabilisation
\\\

---

## 2. add_user.ps1 (Interactive Management Menu)

### Objectif
Interface interactive pour gérer l'annuaire Active Directory (utilisateurs, groupes, partages).

### Flux d'exécution
1. Vérification du conteneur actif
2. Boucle infinie : affichage menu → lecture choix → exécution action
3. 13 options couvrant : users, groupes, partages, tests

### Sections principales

**Encodage UTF-8 (Lignes 1-3)**
\\\powershell
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
\\\
- Permet l'affichage correct des caractères français

**Module Utilisateurs**
- Get-UserList : Liste les utilisateurs via samba-tool
- Add-SambaUser : Crée un utilisateur (mot de passe sécurisé)
- Remove-SambaUser : Supprime avec verrous de sécurité (pas Admin, krbtgt, Guest, dns-*)

**Module Groupes**
- Get-GroupList : Liste les groupes de sécurité
- Add-SambaGroup : Crée un groupe
- Remove-SambaGroup : Supprime (avec verrous natifs AD)
- Manage-GroupMembers : Ajoute/retire utilisateurs des groupes

**Module Partages**
- Get-SambaShareList : Liste les partages via manage_shares.sh
- Add-SambaShare : Crée partage (appelle manage_shares.sh add)
- Remove-SambaShare : Supprime partage (verrous : sysvol, netlogon)
- Modify-SharePermissions : Applique ACLs (read/write)

**Sécurité intégrée**
\\\powershell
if (\ -match "^(Administrator|krbtgt|Guest|dns-.*)$") {
    Write-Host "[!] Verrou de sécurité"
    Pause ; return
}
\\\
- Regex refuse comptes système
- Confirmation obligatoire avant suppression

---

## 3. test.ps1 (Automated Validation Suite)

### Objectif
Valider automatiquement que Samba et les ACLs fonctionnent correctement.

### Test 1 : Validation syntaxe (testparm)
\\\powershell
\ = docker exec -i \ testparm -s 2>&1
if (\ -match "Loaded services file OK") { Write-Host "[OK]" }
\\\
- Vérifie que smb.conf est valide

### Test 2 : Matrice d'accès (ACL)
\\\powershell
Invoke-SambaTest -Title "Accès de 'moi' sur 'amoi'" \
  -Share "amoi" -User "moi" -Password "Root4242" \
  -Command "ls" -ExpectedStatus "SUCCESS"

Invoke-SambaTest -Title "Refus 'toi' sur 'amoi'" \
  -Share "amoi" -User "toi" -Password "Root4242" \
  -Command "ls" -ExpectedStatus "DENIED"
\\\

**Logique de test**
\\\powershell
\ = \ -match "NT_STATUS_ACCESS_DENIED"
if (\ -eq 'DENIED') {
    if (\) { [OK] } else { [FAIL] }
} else {
    if (\) { [FAIL] } else { [OK] }
}
\\\

**Cas testés**
- Partages privés : utilisateur autorisé ✓, autres ✗
- Partage public : tous ✓
- Partages d'échange : droit asymétriques

---

## 4. Dockerfile (Container Image)

### Objectif
Définir l'image Docker contenant Samba4 AD DC.

### Étapes clés

\\\dockerfile
FROM ubuntu:latest
ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
    samba samba-ad-dc samba-dsdb-modules \
    samba-vfs-modules winbind libnss-winbind \
    smbclient cifs-utils acl ...

COPY ./linux/l-start.sh /ok.sh
COPY ./cmd /cmd
RUN chmod +x /ok.sh && chmod +x /cmd/*.sh

EXPOSE 53 88 135 137 138 139 389 445 464 636 3268 3269
ENTRYPOINT ["/ok.sh"]
\\\

**Paquets critiques**
- samba : démon SMB/AD
- samba-ad-dc : composants Domain Controller
- samba-dsdb-modules : base de données AD
- winbind : intégration AD ↔ Linux
- libnss-winbind : résolution utilisateurs AD

**Ports exposés**
- 53 : DNS
- 88 : Kerberos
- 135-139 : NetBIOS/SMB
- 389, 636 : LDAP
- 3268-3269 : Global Catalog

---

## 5. linux/l-start.sh (Container Initialization Orchestrator)

### Objectif
Orchestrer l'initialisation du domaine AD au démarrage.

### Flux d'exécution

\\\ash
SAMBA_DB="/var/lib/samba/private/sam.ldb"
if [ ! -f "\" ]; then
    # Premier démarrage : exécuter init scripts
    for script in /cmd/1un.sh /cmd/2deux.sh /cmd/3trois.sh
    do
        bash "\"
    done
else
    # Redémarrage : domaine existe, skip init
    echo "[*] Domaine déjà opérationnel"
fi

exec /usr/sbin/samba -F -i  # Démarrer Samba en foreground
\\\

**Idempotence**
- Mécanisme : détecte existence de sam.ldb
- Bénéfice : redémarrage sans réinitialisation
- Réinitialisation : docker compose down -v (supprime volumes)

**Scripts exécutés**
1. 1un.sh : Provision domaine
2. 2deux.sh : Création users/groupes
3. 3trois.sh : Création partages
4. manage_shares.sh : IGNORÉ (outil, pas init)

---

## 6. cmd/1un.sh (Domain Provisioning)

### Objectif
Créer la forêt AD SAE.LOCAL et la base de domaine.

### Code clé

\\\ash
rm -rf /var/lib/samba/private/* /var/lib/samba/sysvol/*
samba-tool domain provision \
  --server-role=dc \
  --use-rfc2307 \
  --dns-backend=SAMBA_INTERNAL \
  --realm=SAE.LOCAL \
  --domain=SAE \
  --adminpass="Root4242"
\\\

**Paramètres**
- --server-role=dc : Domain Controller
- --use-rfc2307 : Support attributs POSIX (uid, gid)
- --dns-backend=SAMBA_INTERNAL : DNS intégré
- --realm=SAE.LOCAL : Forêt Kerberos
- --domain=SAE : Domaine NetBIOS
- --adminpass=Root4242 : Mot de passe admin

**Résultat**
- /var/lib/samba/private/sam.ldb : Base domaine
- /var/lib/samba/sysvol/ : Scripts logon
- /etc/samba/smb.conf : Config basique

---

## 7. cmd/2deux.sh (User & Group Creation)

### Objectif
Créer utilisateurs de test et groupes de sécurité.

### Code clé

\\\ash
samba-tool group add cmoi
samba-tool group add ctoi
samba-tool group add cnous

samba-tool user create moi "Root4242" \
  --given-name=Moi --surname=SAE \
  --mail-address=moi@domain.org --login-shell=/bin/bash

samba-tool group addmembers cmoi moi
samba-tool group addmembers ctoi toi
samba-tool group addmembers cnous nous
\\\

**Résultat**
| Utilisateur | Groupe | Mot de passe |
|---|---|---|
| moi | cmoi | Root4242 |
| toi | ctoi | Root4242 |
| nous | cnous | Root4242 |

---

## 8. cmd/3trois.sh (Share Configuration)

### Objectif
Créer arborescence des partages et injecter configs smb.conf.

### Code clé

\\\ash
mkdir -p /partage/{amoi,atoi,anous,public,amoi-atoi,amoi-anous}
chmod -R 777 /partage  # Droits POSIX permissifs (Samba gère sécurité)

cat << 'EOF' >> /etc/samba/smb.conf
[amoi]
    path = /partage/amoi
    read only = yes
    valid users = @cmoi
    write list = @cmoi

[public]
    path = /partage/public
    read only = no
    valid users = @cmoi, @ctoi, @cnous
    write list = @cmoi, @ctoi, @cnous
EOF
\\\

**Logique d'accès**
\\\
read only = yes
valid users = @cmoi
write list = @cmoi
→ cmoi peut lire+écrire, autres ne peuvent pas accéder

read only = no
valid users = tous
write list = tous
→ Tous peuvent lire+écrire (public)

read only = yes
valid users = @cmoi, @ctoi
write list = @cmoi
→ cmoi peut écrire, ctoi peut lire seul
\\\

---

## 9. cmd/manage_shares.sh (Dynamic Share Management)

### Objectif
Ajouter/supprimer/modifier partages SANS redémarrer le conteneur.

### Actions supportées

**list**
\\\ash
testparm -s 2>/dev/null | awk '/^\[/ {print "\n" \}'
\\\
- Affiche tous les partages valides

**add**
\\\ash
ACTION="add"
SHARE_NAME="\"
SHARE_PATH="\"

mkdir -p "\"
chmod 777 "\"
cat << EOF >> /etc/samba/smb.conf

[\]
    path = \
    read only = no
    browseable = yes
EOF
smbcontrol all reload-config
\\\
- Crée répertoire
- Ajoute section smb.conf
- Recharge Samba en mémoire (sans redémarrage)

**remove**
\\\ash
awk -v share="[\]" '
    \ ~ "^\\[.*\\]\$" { in_target = (\ == share) }
    !in_target { print }
' "\" > "\.tmp" && mv "\.tmp" "\"
smbcontrol all reload-config
\\\
- Utilise awk pour supprimer la section
- Atomic write : crée .tmp, puis mv (évite corruption)

**perms**
\\\ash
TARGET="\"
PERM_TYPE="\"

if [ "\" == "read" ]; then
    setfacl -m u:"\":rx "\" 2>/dev/null || \
    setfacl -m g:"\":rx "\"
elif [ "\" == "write" ]; then
    setfacl -m u:"\":rwx "\" 2>/dev/null || \
    setfacl -m g:"\":rwx "\"
fi
\\\
- Applique ACLs POSIX synchronisées avec AD
- Tente user (u:) d'abord, puis groupe (g:)

---

## Flux d'exécution complet (Intégration)

\\\
Windows
  ↓
w-start.ps1 (démarre Docker)
  ↓
Docker Container démarre
  ↓
linux/l-start.sh exécute
  ├─→ 1un.sh : samba-tool domain provision
  ├─→ 2deux.sh : samba-tool user/group create
  ├─→ 3trois.sh : mkdir + smb.conf injection
  ↓
samba -F -i (démon actif)
  ↓
Windows add_user.ps1 (interface interactive)
  ├─→ docker exec samba-tool user list
  ├─→ docker exec samba-tool user create
  ├─→ docker exec bash manage_shares.sh add/remove/perms
  ↓
Windows test.ps1 (validation)
  ├─→ docker exec testparm (syntaxe)
  ├─→ docker exec smbclient (ACL tests)
\\\

---

## Dépendances entre scripts

\\\
w-start.ps1
  ├─→ Dockerfile (image)
  ├─→ docker-compose.yml (container config)
  └─→ linux/l-start.sh (init container)
       ├─→ cmd/1un.sh (provision)
       ├─→ cmd/2deux.sh (users/groups)
       ├─→ cmd/3trois.sh (shares config)
       └─→ cmd/manage_shares.sh (util, pas init)

add_user.ps1
  ├─→ w-start.ps1 (dépend de container actif)
  └─→ docker exec (appelle samba-tool ou manage_shares.sh)

test.ps1
  ├─→ w-start.ps1 (dépend de container actif)
  └─→ docker exec (appelle testparm ou smbclient)
\\\

---

## Résumé des ports et services

| Port | Service | Rôle |
|------|---------|------|
| 53 | DNS | Résolution de noms domaine |
| 88 | Kerberos | Authentification |
| 135-139 | NetBIOS | Protocol SMB hérité |
| 389 | LDAP | Requêtes annuaire |
| 445 | SMB | Partages fichiers |
| 464 | Kerberos ChangePW | Changement mot de passe |
| 636 | LDAPS | LDAP chiffré |
| 3268-3269 | Global Catalog | Requêtes multi-domaines |

---

## Configuration Samba résumée

\\\
Realm : SAE.LOCAL (Kerberos)
Domain : SAE (NetBIOS)
AdminPass : Root4242

Utilisateurs :
  - moi / Root4242 (groupe cmoi)
  - toi / Root4242 (groupe ctoi)
  - nous / Root4242 (groupe cnous)

Partages :
  - amoi : privé cmoi
  - atoi : lecture cmoi+ctoi, écriture ctoi
  - anous : lecture cmoi+ctoi+cnous, écriture cnous
  - public : lecture+écriture tous
  - amoi-atoi : lecture+écriture cmoi, lecture ctoi
  - amoi-anous : lecture+écriture cmoi, lecture cnous
\\\

