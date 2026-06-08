#!/bin/bash
# /cmd/manage_shares.sh
# Script de gestion dynamique des partages Samba AD

ACTION=$1
SHARE_NAME=$2
SMB_CONF="/etc/samba/smb.conf"

# 1. Vérification de la présence d'une action
if [ -z "$ACTION" ]; then
    echo "[-] Erreur : Action manquante."
    echo "Usage: $0 {list|add|remove|perms} [ShareName] [args...]"
    exit 1
fi

# 2. Vérification du nom de partage si l'action n'est pas "list"
if [ "$ACTION" != "list" ] && [ -z "$SHARE_NAME" ]; then
    echo "[-] Erreur : Nom du partage requis pour cette action."
    echo "Usage: $0 {add|remove|perms} <ShareName> [args...]"
    exit 1
fi

reload_samba() {
    # smbcontrol recharge la configuration en mémoire sans couper les connexions actives (plus propre qu'un systemctl restart)
    smbcontrol all reload-config
    echo "[+] Configuration Samba rechargée en mémoire."
}

case "$ACTION" in
    list)
        echo "[*] Partages Samba actuellement actifs et valides :"
        # Utilisation de testparm pour garantir la lecture de la config effectivement chargée (ignore les commentaires et erreurs)
        testparm -s 2>/dev/null | awk '/^\[/ {print "\n" $0} /^[[:space:]]*path =/ {print "  -> "$0}'
        ;;

    add)
        SHARE_PATH=$3
        if [ -z "$SHARE_PATH" ]; then
            echo "[-] Erreur : Chemin du partage requis."
            exit 1
        fi
        
        # Vérification d'existence du bloc
        if grep -q -i "^\[$SHARE_NAME\]" "$SMB_CONF"; then
            echo "[-] Le partage [$SHARE_NAME] existe déjà."
            exit 1
        fi

        echo "[*] Initialisation du répertoire $SHARE_PATH..."
        mkdir -p "$SHARE_PATH"
        # Droits POSIX permissifs par défaut (la granularité de sécurité sera gérée par les ACLs via Samba/AD)
        chmod 777 "$SHARE_PATH" 

        echo "[*] Injection du bloc de configuration..."
        cat <<EOF >> "$SMB_CONF"

[$SHARE_NAME]
    path = $SHARE_PATH
    read only = no
    browseable = yes
EOF
        reload_samba
        ;;

    remove)
        if ! grep -q -i "^\[$SHARE_NAME\]" "$SMB_CONF"; then
            echo "[-] Le partage [$SHARE_NAME] est introuvable."
            exit 1
        fi

        echo "[*] Purge de la section [$SHARE_NAME]..."
        # Exclusion de la section cible avec awk et écriture atomique
        awk -v share="[$SHARE_NAME]" '
            $0 ~ "^\\[.*\\]$" { in_target = ($0 == share) }
            !in_target { print }
        ' "$SMB_CONF" > "${SMB_CONF}.tmp" && mv "${SMB_CONF}.tmp" "$SMB_CONF"
        
        reload_samba
        ;;

    perms)
        TARGET=$3
        PERM_TYPE=$4
        
        # Extraction dynamique du chemin associé au partage depuis le smb.conf
        SHARE_PATH=$(awk -v share="[$SHARE_NAME]" '$0 ~ "^\\[.*\\]$" {in_target = ($0 == share)} in_target && $1 == "path" {print $3}' "$SMB_CONF")
        
        if [ -z "$SHARE_PATH" ]; then
            echo "[-] Impossible de résoudre le chemin pour [$SHARE_NAME]."
            exit 1
        fi

        echo "[*] Application des ACLs POSIX (synchronisées avec l'AD via vfs_acl_xattr) sur $SHARE_PATH..."
        if [ "$PERM_TYPE" == "read" ]; then
            # Tente d'appliquer à un user (u:), si échec tente un groupe (g:)
            setfacl -m u:"$TARGET":rx "$SHARE_PATH" 2>/dev/null || setfacl -m g:"$TARGET":rx "$SHARE_PATH"
        elif [ "$PERM_TYPE" == "write" ]; then
            setfacl -m u:"$TARGET":rwx "$SHARE_PATH" 2>/dev/null || setfacl -m g:"$TARGET":rwx "$SHARE_PATH"
        else
            echo "[-] Type de permission invalide (read/write attendu)."
            exit 1
        fi
        
        echo "[+] Permission '$PERM_TYPE' appliquée pour '$TARGET'."
        ;;

    *)
        echo "[-] Action inconnue : $ACTION"
        exit 1
        ;;
esac