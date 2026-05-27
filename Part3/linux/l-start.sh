#!/bin/bash
set -e

SAMBA_DB="/var/lib/samba/private/sam.ldb"

if [ ! -f "$SAMBA_DB" ]; then
    echo "[*] Aucun domaine détecté. Lancement de la séquence de provisionnement..."

    # Sécurité : on active nullglob pour éviter que *.sh ne devienne une string littérale si vide
    shopt -s nullglob
    scripts=(/cmd/*.sh)
    
    # Check critique : si le tableau est vide, on coupe tout
    if [ ${#scripts[@]} -eq 0 ]; then
        echo "[!] ERREUR CRITIQUE : Aucun script d'initialisation trouvé dans /cmd/ !"
        echo "[!] Vérifie ton Dockerfile et ton arborescence locale."
        exit 1
    fi

    for script in "${scripts[@]}"; do
        if [ -x "$script" ]; then
            echo "=================================================="
            echo "[->] Exécution de $script"
            echo "=================================================="
            "$script"
        else
            echo "[!] ERREUR : Le script $script n'est pas exécutable."
            exit 1
        fi
    done

    echo "[+] Séquence de provisionnement terminée avec succès."
else
    echo "[*] Base SAM détectée. Le domaine SAE.LOCAL est déjà opérationnel."
fi
# ... (le reste du script au-dessus reste identique)

echo "[*] Démarrage du démon Samba Active Directory..."
exec /usr/sbin/samba -F -i