# 📋 SAE 2.04 - Infrastructure Active Directory avec Samba4

## 🎯 Objectif

Ce projet vise à **créer une infrastructure Active Directory (AD) complète** en utilisant **Samba4** dans un conteneur Docker. Il s'agit d'une solution d'entreprise pour la gestion des utilisateurs, des partages réseau (shares) et des droits d'accès.

---

## 📚 Documentation

- **Rapport détaillé** : Voir `Création dune infrastructure AD avec Samba4.pdf` pour la documentation complète du projet.

---

## 🏗️ Architecture

### Infrastructure
```
┌─────────────────────────────────────┐
│     Docker Container (srv-ubuntu)   │
│  ┌───────────────────────────────┐  │
│  │    Samba4 AD-DC               │  │
│  │  - Serveur DNS (port 53)      │  │
│  │  - LDAP/Kerberos (port 88)    │  │
│  │  - SMB Shares (port 445)      │  │
│  │  - NETBIOS (ports 137/138)    │  │
│  └───────────────────────────────┘  │
│  ┌───────────────────────────────┐  │
│  │  FastAPI Web Interface        │  │
│  │  (Gestion des utilisateurs)   │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

### Services exposés
- **DNS** : Port 53 (UDP)
- **Kerberos** : Port 88 (TCP/UDP)
- **NetBIOS** : Ports 137-138 (UDP)
- **SMB** : Ports 139, 445 (TCP)
- **LDAP** : Port 389 (TCP)
- **Web API** : Port 8000 (FastAPI)

---

## 🚀 Démarrage Rapide

### Prérequis
- Docker et Docker Compose installés
- PowerShell (pour Windows)
- Au minimum 2GB de RAM disponible

### Lancement

#### Sur Windows (PowerShell)
```powershell
.\w-start.ps1
```
Ce script :
1. ✅ Nettoie l'ancien environnement
2. ✅ Construit l'image Docker
3. ✅ Lance le conteneur
4. ✅ Vérifie que Samba est opérationnel

#### Sur Linux/Mac (Bash)
```bash
./linux/l-start.sh
```

### Vérification du statut
```bash
docker ps
# Vous devriez voir le conteneur "srv-ubuntu" en cours d'exécution
```

### Accès au conteneur
```bash
docker exec -it srv-ubuntu bash
```

---

## 📂 Structure du Projet

```
SAE-2.04/Part3/
├── Dockerfile                          # Configuration du conteneur
├── docker-compose.yml                  # Orchestration Docker
├── w-start.ps1                         # Script de démarrage (Windows)
├── add_user.ps1                        # Script d'ajout d'utilisateur (Windows)
├── test.ps1                            # Tests PowerShell
├── linux/
│   ├── l-start.sh                      # Script de démarrage (Linux)
│   └── sambatest.sh                    # Tests de Samba
├── cmd/
│   ├── 1un.sh                          # Étape 1 : Provisionning du domaine
│   ├── 2deux.sh                        # Étape 2 : Configuration Samba
│   ├── 3trois.sh                       # Étape 3 : Finalisations
│   └── manage_shares.sh                # Gestion des partages réseau
├── readme.md                           # Ce fichier
└── Création dune infrastructure AD avec Samba4.pdf  # Documentation détaillée
```

---

## 🔧 Gestion des Utilisateurs et Partages

### 1️⃣ Ajouter un utilisateur (Windows)
```powershell
.\add_user.ps1 -Username "jdoe" -Password "SecurePassword123!"
```

### 2️⃣ Gérer les partages depuis le conteneur
```bash
# Accéder au conteneur
docker exec -it srv-ubuntu bash

# Afficher les partages actifs
net share

# Créer un nouveau partage
/cmd/manage_shares.sh create sharename /path/to/share "Description"

# Supprimer un partage
/cmd/manage_shares.sh delete sharename

# Modifier un partage
/cmd/manage_shares.sh modify sharename /newpath
```

### 3️⃣ Se connecter via SMB (depuis un client)
```bash
# Sur Linux/Mac
smbclient -L //172.20.0.10 -U Administrator

# Monter un partage
mount -t cifs //172.20.0.10/sharename /mnt/partage -o username=user,password=pass
```

---

## 🧪 Tests

### Tests Windows
```powershell
.\test.ps1
```

### Tests Linux
```bash
./linux/sambatest.sh
```

Ces scripts vérifient :
- ✅ La connectivité au serveur Samba
- ✅ L'authentification Kerberos
- ✅ Les partages réseau
- ✅ Les permissions LDAP

---

## 📊 Accès à la Web Interface (API)

Une interface FastAPI pour gérer l'AD est disponible :

**URL** : `http://localhost:8000`

### Endpoints principaux
- `GET /users` - Lister tous les utilisateurs
- `POST /users` - Créer un nouvel utilisateur
- `DELETE /users/{id}` - Supprimer un utilisateur
- `GET /shares` - Lister les partages
- `POST /shares` - Créer un partage
- `PATCH /shares/{id}` - Modifier un partage

---

## ⚙️ Configuration Avancée

### Paramètres Samba
Modifiables dans `/etc/samba/smb.conf` du conteneur :

```bash
docker exec -it srv-ubuntu nano /etc/samba/smb.conf
```

Après modification :
```bash
docker exec -it srv-ubuntu smbcontrol all reload-config
```

### Réseau Docker
Le réseau est configuré en bridge avec l'IP statique `172.20.0.10` :

```yaml
# docker-compose.yml
networks:
  sae_network:
    ipv4_address: 172.20.0.10
```

---

## 🐛 Dépannage

### Le conteneur crash au démarrage
```bash
docker logs srv-ubuntu
```
Vérifiez les permissions du répertoire `/var/lib/samba`

### Impossible de se connecter au partage SMB
1. Vérifiez que le port 445 n'est pas bloqué
2. Testez la connectivité : `smbclient -L //172.20.0.10`
3. Vérifiez les credentials dans `smb.conf`

### Erreur Kerberos
```bash
docker exec -it srv-ubuntu kinit administrator@SAMBADOM.LOCAL
docker exec -it srv-ubuntu klist
```

### Réinitialiser complètement l'environnement
```bash
docker compose down -v
docker image rm sae-samba
./w-start.ps1  # ou ./linux/l-start.sh
```

---

## 📝 Notes d'Implémentation

### Étapes du provisioning
1. **1un.sh** : Provisionne le domaine Samba AD (`samba-tool domain provision`)
2. **2deux.sh** : Configure Samba en tant que contrôleur de domaine
3. **3trois.sh** : Applique les dernières configurations et démarre les services

### Gestion des partages
Le script `manage_shares.sh` automatise la création/modification/suppression de partages tout en maintenant les bonnes permissions ACL.

---

## 🔐 Sécurité

⚠️ **IMPORTANT pour la PRODUCTION** :
- Changez le mot de passe administrateur par défaut
- Configurez un firewall approprié
- Utilisez LDAPS (LDAP sur SSL/TLS) pour les connexions à distance
- Activez l'audit Samba (`log level = 3`)
- Mettez à jour régulièrement le conteneur

---

## 📞 Support et Contributions

Pour tout problème ou amélioration :
1. Consultez le PDF de documentation
2. Vérifiez les logs Docker
3. Testez les scripts individuellement

---

## 📄 Licence

Projet d'études - SAE 2.04

---

**Dernière mise à jour** : Juin 2026
