# 🏗️ Architecture et Flux d'Exécution - SAE 2.04 Part3

## 📌 Vue d'ensemble

Ce document explique **comment tous les fichiers de Part3 interagissent** pour créer une infrastructure complète d'Active Directory avec Samba4.

---

## 🔄 Flux d'Exécution Global

```
┌─────────────────────────────────────────────────────────────────┐
│                    Démarrage de l'infrastructure                │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                     ┌────────────────┐
                     │  w-start.ps1   │ (Windows)
                     │   l-start.sh   │ (Linux)
                     └────────────────┘
                              ↓
              ┌───────────────────────────────┐
              │  docker compose up --build    │
              │  (Construit l'image Docker)   │
              └───────────────────────────────┘
                              ↓
              ┌───────────────────────────────┐
              │   Dockerfile exécuté          │
              │   (Lance /ok.sh)              │
              └───────────────────────────────┘
                              ↓
              ┌───────────────────────────────┐
              │  linux/l-start.sh             │
              │  (Orchestre l'initialisation) │
              └───────────────────────────────┘
                              ↓
              ┌───────────────────────────────┐
              │  cmd/*.sh scripts             │
              │  1. Provision AD              │
              │  2. Créer users/groups        │
              │  3. Configurer partages       │
              └───────────────────────────────┘
                              ↓
              ┌───────────────────────────────┐
              │  Samba opérationnel           │
              │  Prêt pour add_user.ps1       │
              └───────────────────────────────┘
```

---

## 📁 Détail de Chaque Fichier et Interaction

### 🔧 **Fichiers Windows (PowerShell)**

#### 1. **w-start.ps1** - Script de Démarrage
```
OBJECTIF : Lancer et vérifier le démarrage du conteneur Docker
FLUX :
  1. Affiche un message d'accueil coloré
  2. Exécute : docker compose down -v (nettoyage)
  3. Exécute : docker compose up -d --build
  4. Attend 5 secondes (initialisation Samba)
  5. Vérifie que le conteneur est bien running
  6. SUCCÈS ou erreur critique
```

**Dépendances** :
- `docker-compose.yml` ← Définit la configuration du conteneur
- `Dockerfile` ← Construit l'image

**Déclenche** :
- → `Dockerfile` → `linux/l-start.sh` → `cmd/*.sh`

---

#### 2. **add_user.ps1** - Menu Interactif de Gestion
```
OBJECTIF : Interface complète de gestion de l'AD depuis Windows
FONCTIONNALITÉS (13 options de menu) :

┌─ UTILISATEURS (options 1-3)
│  1. Lister les utilisateurs          → docker exec samba-tool user list
│  2. Ajouter un utilisateur           → docker exec samba-tool user create
│  3. Supprimer un utilisateur         → docker exec samba-tool user delete
│
├─ GROUPES (options 4-7)
│  4. Lister les groupes               → docker exec samba-tool group list
│  5. Créer un groupe de sécurité      → docker exec samba-tool group add
│  6. Supprimer un groupe              → docker exec samba-tool group delete
│  7. Gérer les membres d'un groupe    → docker exec samba-tool group addmembers/removemembers
│
├─ PARTAGES (options 8-11)
│  8. Voir les partages Samba          → docker exec bash manage_shares.sh list
│  9. Ajouter un partage               → docker exec bash manage_shares.sh add
│  10. Supprimer un partage            → docker exec bash manage_shares.sh remove
│  11. Modifier les permissions        → docker exec bash manage_shares.sh perms
│
└─ TESTS (option 12)
   12. Tester la connexion d'un user   → Appelle test.ps1
```

**Sécurité intégrée** :
- Empêche la suppression des utilisateurs/groupes système
- Demande une confirmation avant suppression
- Bloque les modifications sur sysvol/netlogon

**Communication** :
- ↔️ Conteneur via `docker exec` (exécute les commandes Samba)
- → `manage_shares.sh` (gestion des partages)
- → `test.ps1` (validation des connexions)

---

#### 3. **test.ps1** - Suite de Tests Automatiques
```
OBJECTIF : Valider les ACLs, permissions et connectivité
TESTS EFFECTUÉS :

1. Validation syntaxique
   → testparm -s (vérifie smb.conf)

2. Tests d'authentification et accès
   ✓ Utilisateur 'moi' accède à partage 'amoi'     [SUCCESS]
   ✗ Utilisateur 'toi' accède à partage 'amoi'     [DENIED]
   ✓ Utilisateur 'nous' accède à partage 'public'  [SUCCESS]
   ✗ Utilisateur 'nous' écrit dans 'amoi-atoi'     [DENIED]

RÉSULTAT : Rapporte les échecs/succès avec détails

APPEL PAR :
  - add_user.ps1 (option 12)
  - Peut être lancé indépendamment : ./test.ps1
```

---

### 🐧 **Fichiers Linux/Docker**

#### 4. **Dockerfile** - Construction de l'Image
```dockerfile
# Base
FROM ubuntu:latest

# Installation des paquets
RUN apt install -y \
    samba samba-ad-dc samba-ad-provision \  # Core Samba
    python3-fastapi python3-uvicorn \       # Web API
    acl smbclient cifs-utils \              # Tools
    ... autres paquets ...

# Copie des scripts
COPY ./linux/l-start.sh /ok.sh
COPY ./cmd /cmd

# Permissions exécution
RUN chmod +x /ok.sh && chmod +x /cmd/*.sh

# Point d'entrée
ENTRYPOINT ["/ok.sh"]
```

**Rôle** :
- Définit l'environnement Docker complet
- Lance `/ok.sh` au démarrage du conteneur
- Expose les ports Samba

---

#### 5. **linux/l-start.sh** - Orchestrateur d'Initialisation
```bash
OBJECTIF : Gérer l'initialisation du domaine Samba

LOGIQUE :
  1. Vérifie l'existence de /var/lib/samba/private/sam.ldb
     ├─ SI n'existe pas → Domaine JAMAIS créé
     │  └─ Exécute TOUS les scripts de /cmd/ dans l'ordre :
     │     1. 1un.sh          (provision du domaine)
     │     2. 2deux.sh        (création utilisateurs/groupes)
     │     3. 3trois.sh       (configuration partages)
     │     └─ Ignore manage_shares.sh (outil, pas init)
     │
     └─ SI existe → Domaine DÉJÀ opérationnel
        └─ Skip l'initialisation (idempotent)

  2. Démarre le démon Samba
     → exec /usr/sbin/samba -F -i (foreground + debug)

SÉCURITÉ IDEMPOTENTE :
  - Peut être relancé sans casser l'AD existant
  - Drapeaux 'set -e' pour arrêter sur erreur critique
```

**Déclenché par** :
- `Dockerfile` au démarrage du conteneur

**Appelle** :
- → `cmd/1un.sh`
- → `cmd/2deux.sh`
- → `cmd/3trois.sh`

---

### 🔧 **Scripts d'Initialisation (cmd/)**

#### 6. **cmd/1un.sh** - Provision du Domaine AD
```bash
ÉTAPE 1 : Nettoyage
  1. Supprime /etc/samba/smb.conf ancien
  2. Supprime /var/lib/samba/private/* (certs, LDAP)
  3. Supprime /var/lib/samba/sysvol/* (policies)

ÉTAPE 2 : Provisionne un nouveau domaine
  samba-tool domain provision \
    --server-role=dc \           # Contrôleur de domaine
    --realm=SAE.LOCAL \          # Domaine DNS
    --domain=SAE \               # Domaine NetBIOS court
    --adminpass="Root4242" \     # Mot de passe administrateur
    --dns-backend=SAMBA_INTERNAL # Serveur DNS interne

RÉSULTAT :
  ✓ Base AD créée (/var/lib/samba/private/sam.ldb)
  ✓ smb.conf généré automatiquement (base)
  ✓ Certs Kerberos générés
  ✓ Zone DNS créée

ORDRE EXÉCUTION : 1️⃣ (doit être PREMIER)
```

---

#### 7. **cmd/2deux.sh** - Création Utilisateurs et Groupes
```bash
ÉTAPE 2 : Création des données AD

1. GROUPES DE SÉCURITÉ
   samba-tool group add cmoi       # Groupe pour 'moi'
   samba-tool group add ctoi       # Groupe pour 'toi'
   samba-tool group add cnous      # Groupe pour 'nous'

2. UTILISATEURS
   samba-tool user create moi "Root4242"      # Utilisateur 'moi'
   samba-tool user create toi "Root4242"      # Utilisateur 'toi'
   samba-tool user create nous "Root4242"     # Utilisateur 'nous'

3. ASSIGNATION AUX GROUPES
   samba-tool group addmembers cmoi moi       # moi → groupe cmoi
   samba-tool group addmembers ctoi toi       # toi → groupe ctoi
   samba-tool group addmembers cnous nous     # nous → groupe cnous

DONNÉES CRÉÉES (pour test.ps1) :
  Utilisateurs : moi, toi, nous (tous avec pass "Root4242")
  Groupes : cmoi, ctoi, cnous

ORDRE EXÉCUTION : 2️⃣ (après 1un.sh)
```

---

#### 8. **cmd/3trois.sh** - Configuration des Partages
```bash
ÉTAPE 3 : Setup des partages réseau

1. CRÉATION DE L'ARBORESCENCE PHYSIQUE
   mkdir -p /partage/{amoi,atoi,anous,public,amoi-atoi,amoi-anous}
   chmod -R 777 /partage

2. INJECTION DES PARTAGES DANS SMB.CONF
   Ajoute 6 blocs [NomPartage] avec :
   - path = chemin physique
   - read only = oui/non
   - valid users = groupes autorisés
   - write list = groupes pouvant écrire

PARTAGES CRÉÉS :
┌─────────────────┬──────────────┬────────────────────┬─────────────┐
│ Partage         │ Accès Lecture │ Accès Écriture     │ Répertoire  │
├─────────────────┼──────────────┼────────────────────┼─────────────┤
│ [amoi]          │ @cmoi        │ @cmoi              │ /partage/a  │
│ [atoi]          │ @cmoi,@ctoi  │ @ctoi              │ /partage/at │
│ [anous]         │ tous         │ @cnous             │ /partage/an │
│ [public]        │ tous         │ tous               │ /partage/pu │
│ [amoi-atoi]     │ @cmoi,@ctoi  │ @cmoi              │ /partage/am │
│ [amoi-anous]    │ @cmoi,@cnous │ @cmoi              │ /partage/am │
└─────────────────┴──────────────┴────────────────────┴─────────────┘

ORDRE EXÉCUTION : 3️⃣ (après 2deux.sh)
```

---

#### 9. **cmd/manage_shares.sh** - Outil de Gestion Dynamique
```bash
OBJECTIF : Gérer les partages APRÈS l'initialisation (outil réutilisable)

SYNTAXE :
  ./manage_shares.sh {list|add|remove|perms} [args...]

COMMANDES :

1. LIST (Lister les partages)
   ./manage_shares.sh list
   → Affiche tous les partages via testparm

2. ADD (Créer un partage)
   ./manage_shares.sh add ShareName /path/to/share
   → Crée le répertoire
   → Injecte la section [ShareName] dans smb.conf
   → Recharge Samba (smbcontrol all reload-config)

3. REMOVE (Supprimer un partage)
   ./manage_shares.sh remove ShareName
   → Supprime la section [ShareName] du smb.conf
   → Recharge Samba

4. PERMS (Modifier les permissions)
   ./manage_shares.sh perms ShareName USERNAME {read|write}
   → Applique les ACLs POSIX (setfacl)
   → Synchronisées avec l'AD via vfs_acl_xattr

RECHARGE INTELLIGENTE :
  smbcontrol all reload-config
  → Recharge en mémoire sans couper les connexions actives
  → Plus propre que systemctl restart

APPELÉ PAR :
  - add_user.ps1 (options 9, 10, 11)
  - Utilisable indépendamment depuis le conteneur
```

---

## 🔗 Interactions et Dépendances

### Ordre d'Exécution Complet
```
1. Utilisateur lance w-start.ps1
   ↓
2. w-start.ps1 → docker compose up --build
   ↓
3. Dockerfile construit l'image et lance /ok.sh
   ↓
4. /ok.sh = linux/l-start.sh (vérifie l'initialisation)
   ↓
5. 1un.sh → Crée le domaine AD
   ↓
6. 2deux.sh → Crée utilisateurs et groupes
   ↓
7. 3trois.sh → Configure les partages
   ↓
8. Samba démarre en foreground
   ↓
9. Conteneur prêt → Utilisateur peut utiliser add_user.ps1 ou test.ps1
```

### Appels Dynamiques Après Démarrage
```
add_user.ps1 (Menu)
├─ Option 1-3 : docker exec samba-tool user [list|create|delete]
├─ Option 4-7 : docker exec samba-tool group [list|add|delete|addmembers]
├─ Option 8-11 : docker exec bash manage_shares.sh [list|add|remove|perms]
└─ Option 12 : ./test.ps1 → docker exec smbclient [connexions test]
```

---

## 🔐 Sécurité et Idempotence

### Principes Implémentés

#### **Idempotence**
- `l-start.sh` vérifie si le domaine existe déjà (sam.ldb)
- Si oui : Skip l'initialisation, lance Samba
- Si non : Exécute l'initialisation complète
- **Résultat** : Peut relancer le conteneur sans casser l'AD

#### **Verrous de Sécurité dans add_user.ps1**
```powershell
# Empêche la suppression d'utilisateurs système
if ($username -match "^(Administrator|krbtgt|Guest|dns-.*)$") {
    Write-Host "[!] Verrou de sécurité : Impossible de supprimer"
}

# Empêche la suppression de groupes natifs
if ($groupname -match "^(Administrators|Domain Admins|...)$") {
    Write-Host "[!] Verrou de sécurité : Impossible de supprimer"
}

# Empêche la suppression de partages vitaux
if ($shareName -match "^(sysvol|netlogon)$") {
    Write-Host "[!] Verrou de sécurité : Impossible de supprimer"
}

# Confirmation avant suppression
$confirm = Read-Host "Confirmer la suppression ? (O/N)"
```

#### **Gestion des Erreurs**
- `set -e` dans les scripts shell (arrête sur erreur)
- `$ErrorActionPreference = 'Stop'` dans PowerShell
- Affichage clair des erreurs + suggestions de dépannage

---

## 📊 Communication Conteneur ↔ Host

### Canal de Communication
```
Windows (Host)
    ↓
docker exec -i srv-ubuntu COMMANDE
    ↓
Conteneur Linux (Guest)
    ├─ samba-tool (Commandes AD)
    ├─ smbclient (Tests connexion SMB)
    ├─ testparm (Validation config)
    └─ bash manage_shares.sh (Gestion partages)
    ↓
Résultat affichée dans PowerShell
```

### Ports Exposés
```
172.20.0.10:53      DNS Samba
172.20.0.10:88      Kerberos (auth)
172.20.0.10:135     RPC
172.20.0.10:137-138 NetBIOS
172.20.0.10:139     SMB (ancien)
172.20.0.10:389     LDAP
172.20.0.10:445     SMB3 (moderne) ← Principal
172.20.0.10:3268    LDAP Global Catalog
```

---

## 🧪 Flux de Test

### test.ps1 - Validation Automatique
```
Test 1 : Syntaxe smb.conf
  smbclient→ testparm → OK ou FAIL

Test 2 : Authentification + ACLs
  [Pour chaque utilisateur/partage]
  smbclient -L //172.20.0.10/sharename -U user%pass \
           -c "ls" 2>&1
  ├─ Cherche "NT_STATUS_ACCESS_DENIED" (accès refusé)
  ├─ Cherche "Error" (erreur générale)
  └─ Pas d'erreur = SUCCESS

Résultats :
  [OK]   : Accès autorisé ✓
  [FAIL] : Accès refusé ou erreur ✗
```

---

## 📝 Fichiers de Configuration Modifiés Dynamiquement

### `/etc/samba/smb.conf`
```
Généré par : 1un.sh (samba-tool domain provision)
Modifié par : 3trois.sh (ajout des partages)
Modifié par : manage_shares.sh (ajout/suppression partages)

Structure finale :
[global]
  realm = SAE.LOCAL
  domain = SAE
  server role = active directory domain controller
  ... options samba ...

[sysvol]
  ... (auto-généré par Samba)

[netlogon]
  ... (auto-généré par Samba)

[amoi]
  path = /partage/amoi
  valid users = @cmoi
  ... (ajouté par 3trois.sh)

[public]
  path = /partage/public
  ... (ajouté par 3trois.sh)
```

### `/var/lib/samba/private/sam.ldb`
```
Base de données LDAP/AD complète
Générée par : 1un.sh (samba-tool domain provision)
Modifiée par : 2deux.sh (users/groups)
Interrogée par : samba-tool commands
Interrogée par : test.ps1 (smbclient)

Contient :
  - Utilisateurs (moi, toi, nous, Administrator)
  - Groupes (cmoi, ctoi, cnous)
  - Policies Kerberos
  - Certs SSL/TLS
```

---

## 🎯 Résumé Interactif

| Fichier | Rôle | Déclenche | Modifie |
|---------|------|-----------|---------|
| **w-start.ps1** | Démarrage Docker | docker compose | Aucun fichier |
| **Dockerfile** | Image Docker | linux/l-start.sh | Aucun fichier |
| **l-start.sh** | Orchestration | cmd/*.sh | sam.ldb, smb.conf |
| **1un.sh** | Provision AD | (rien) | sam.ldb, smb.conf |
| **2deux.sh** | Users/Groups | (rien) | sam.ldb |
| **3trois.sh** | Partages | (rien) | smb.conf, /partage/* |
| **manage_shares.sh** | Outil partages | (rien) | smb.conf, /partage/* |
| **add_user.ps1** | Menu gestion | manage_shares.sh | sam.ldb, smb.conf |
| **test.ps1** | Tests ACL | (rien) | Rapport de test |

---

## 🚀 Cas d'Usage Typiques

### **Cas 1 : Démarrage Complet**
```bash
# Utilisateur execute
./w-start.ps1

# Flux : w-start → docker compose → Dockerfile → l-start.sh 
#      → 1un.sh → 2deux.sh → 3trois.sh → Samba ready
# Temps : ~30 secondes
```

### **Cas 2 : Ajouter un Utilisateur**
```bash
# Utilisateur execute
./add_user.ps1

# Sélectionne option 2 : "Ajouter un utilisateur"
# Rentre : jdupont, Jean, Dupont, password123

# Flux : add_user.ps1 → docker exec samba-tool user create 
#      → sam.ldb modifiée → Utilisateur créé immédiatement

# On peut tester : option 12 (test.ps1)
```

### **Cas 3 : Ajouter un Partage**
```bash
# Utilisateur execute
./add_user.ps1

# Sélectionne option 9 : "Ajouter un partage"
# Rentre : Documents, /partage/documents

# Flux : add_user.ps1 → manage_shares.sh add 
#      → mkdir /partage/documents
#      → Injette section [Documents] dans smb.conf
#      → smbcontrol all reload-config
#      → Partage accessible immédiatement via SMB

# Clients Windows voient le partage dans l'explorateur
```

### **Cas 4 : Redémarrage du Conteneur**
```bash
# Conteneur crash ou arrêt intentionnel
docker stop srv-ubuntu

# Utilisateur relance
./w-start.ps1

# Flux : w-start → docker compose up
#      → Dockerfile → l-start.sh
#      → Vérifie sam.ldb existant ✓
#      → SKIP l'initialisation (1un/2deux/3trois)
#      → Lance samba directement
#      → Toutes les données (users, groups, partages) restent intactes
# Temps : ~10 secondes (plus rapide)
```

---

## 🔍 Debugging : Où Chercher

| Problème | Fichier à Vérifier | Commande |
|----------|-------------------|----------|
| Démarrage échoue | Dockerfile + Logs | `docker logs srv-ubuntu` |
| Domaine pas créé | 1un.sh | `ls -la /var/lib/samba/private/sam.ldb` |
| Utilisateurs vides | 2deux.sh | `docker exec srv-ubuntu samba-tool user list` |
| Partages vides | 3trois.sh | `docker exec srv-ubuntu testparm -s` |
| Permissions incorrectes | manage_shares.sh | `docker exec srv-ubuntu getfacl /partage/public` |
| ACL refusé sur test | test.ps1 | `docker exec srv-ubuntu smbclient -L //srv-ubuntu` |

---

**Dernière mise à jour** : Juin 2026
