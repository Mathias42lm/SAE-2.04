# Forcer l'encodage UTF-8 pour la console locale
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

$ContainerName = "srv-ubuntu"

# Vérification d'état du conteneur
$isRunning = (docker ps --format '{{.Names}}') -contains $ContainerName
if (-not $isRunning) {
    Write-Host "[!] Le conteneur $ContainerName n'est pas en cours d'exécution." -ForegroundColor Red
    exit 1
}

function Show-Menu {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "   GESTION DE L'ANNUAIRE AD SAMBA" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "--- UTILISATEURS ---" -ForegroundColor Yellow
    Write-Host "1. Lister les utilisateurs"
    Write-Host "2. Ajouter un utilisateur"
    Write-Host "3. Supprimer un utilisateur"
    Write-Host "--- GROUPES ---" -ForegroundColor Yellow
    Write-Host "4. Lister les groupes"
    Write-Host "5. Créer un groupe de sécurité"
    Write-Host "6. Supprimer un groupe"
    Write-Host "7. Gérer les membres d'un groupe (Ajout/Retrait)"
    Write-Host "--- Partages ---" -ForegroundColor Yellow
    Write-Host "8. Voir les partages Samba" 
    Write-Host "9. Ajouter un partage Samba" 
    Write-Host "10. Supprimer un partage Samba" 
    Write-Host "11. Modifier les permissions d'un partage" 
    Write-Host "--- TESTS ---" -ForegroundColor Yellow
    Write-Host "12. Tester la connexion d'un utilisateur"
    Write-Host "---------" -ForegroundColor Yellow
    Write-Host "13. Quitter"
    Write-Host "========================================" -ForegroundColor Cyan
}

# ---------------------------------------------------------
# MODULE UTILISATEURS
# ---------------------------------------------------------

function Get-UserList {
    Write-Host "`n[*] Liste des utilisateurs du domaine SAE.LOCAL :" -ForegroundColor Yellow
    docker exec -i $ContainerName samba-tool user list
    Pause
}

function Add-SambaUser {
    Write-Host "`n[*] AJOUT D'UN UTILISATEUR" -ForegroundColor Yellow
    $username = Read-Host "Nom d'utilisateur (ex: jdupont)"
    $firstname = Read-Host "Prénom"
    $lastname = Read-Host "Nom de famille"
    
    $securePassword = Read-Host "Mot de passe (Min 8 car, Maj, Min, Chiffre) " -AsSecureString
    
    if ([string]::IsNullOrWhiteSpace($username) -or $securePassword.Length -eq 0) {
        Write-Host "[!] Le nom d'utilisateur et le mot de passe sont obligatoires." -ForegroundColor Red
        Pause ; return
    }

    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    $clearPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

    $mail = "$username@sae.local"
    
    Write-Host "[*] Injection de la commande..." -ForegroundColor Cyan
    $result = docker exec -i $ContainerName samba-tool user create $username $clearPassword --given-name="$firstname" --surname="$lastname" --mail-address="$mail" --login-shell=/bin/bash 2>&1

    if ($result -match "User '$username' added successfully") {
        Write-Host "[+] L'utilisateur $username a été provisionné." -ForegroundColor Green
    } else {
        Write-Host "[-] Échec de l'ajout : $result" -ForegroundColor Red
    }
    Pause
}

function Remove-SambaUser {
    Write-Host "`n[*] SUPPRESSION D'UN UTILISATEUR" -ForegroundColor Yellow
    $username = Read-Host "Nom d'utilisateur à révoquer"
    
    if ([string]::IsNullOrWhiteSpace($username)) { return }

    if ($username -match "^(Administrator|krbtgt|Guest|dns-.*)$") {
        Write-Host "[!] Verrou de sécurité : Impossible de supprimer ce compte système." -ForegroundColor Red
        Pause ; return
    }

    $confirm = Read-Host "Confirmer la suppression de '$username' ? (O/N)"
    if ($confirm -eq 'O' -or $confirm -eq 'o') {
        $result = docker exec -i $ContainerName samba-tool user delete $username 2>&1
        if ($result -match "Deleted user") {
            Write-Host "[+] L'objet $username a été expurgé." -ForegroundColor Green
        } else {
            Write-Host "[-] Échec de la suppression : $result" -ForegroundColor Red
        }
    }
    Pause
}

# ---------------------------------------------------------
# MODULE GROUPES
# ---------------------------------------------------------

function Get-GroupList {
    Write-Host "`n[*] Liste des groupes de sécurité :" -ForegroundColor Yellow
    docker exec -i $ContainerName samba-tool group list
    Pause
}

function Add-SambaGroup {
    Write-Host "`n[*] CRÉATION D'UN GROUPE" -ForegroundColor Yellow
    $groupname = Read-Host "Nom du groupe"
    
    if ([string]::IsNullOrWhiteSpace($groupname)) { return }

    $result = docker exec -i $ContainerName samba-tool group add $groupname 2>&1
    
    if ($result -match "Added group") {
        Write-Host "[+] Le groupe '$groupname' a été créé avec succès." -ForegroundColor Green
    } else {
        Write-Host "[-] Échec de la création : $result" -ForegroundColor Red
    }
    Pause
}

function Remove-SambaGroup {
    Write-Host "`n[*] SUPPRESSION D'UN GROUPE" -ForegroundColor Yellow
    $groupname = Read-Host "Nom du groupe à supprimer"
    
    if ([string]::IsNullOrWhiteSpace($groupname)) { return }

    if ($groupname -match "^(Administrators|Domain Admins|Enterprise Admins|Schema Admins|Domain Users|Domain Computers|Domain Controllers|Cert Publishers|DnsAdmins)$") {
        Write-Host "[!] Verrou de sécurité : Impossible de supprimer un groupe natif AD." -ForegroundColor Red
        Pause ; return
    }

    $confirm = Read-Host "Confirmer la suppression du groupe '$groupname' ? (O/N)"
    if ($confirm -eq 'O' -or $confirm -eq 'o') {
        $result = docker exec -i $ContainerName samba-tool group delete $groupname 2>&1
        if ($result -match "Deleted group") {
            Write-Host "[+] Le groupe '$groupname' a été supprimé." -ForegroundColor Green
        } else {
            Write-Host "[-] Échec de la suppression : $result" -ForegroundColor Red
        }
    }
    Pause
}

function Manage-GroupMembers {
    Write-Host "`n[*] GESTION DES MEMBRES D'UN GROUPE" -ForegroundColor Yellow
    Write-Host "1. Ajouter un utilisateur au groupe"
    Write-Host "2. Retirer un utilisateur du groupe"
    $action = Read-Host "Choix (1 ou 2)"

    if ($action -notin @('1', '2')) { Write-Host "Choix invalide." -ForegroundColor Red ; Pause ; return }

    $groupname = Read-Host "Nom du groupe cible"
    $username = Read-Host "Nom de l'utilisateur"

    if ([string]::IsNullOrWhiteSpace($groupname) -or [string]::IsNullOrWhiteSpace($username)) { return }

    if ($action -eq '1') {
        $result = docker exec -i $ContainerName samba-tool group addmembers $groupname $username 2>&1
        if ($result -match "Added members") {
            Write-Host "[+] L'utilisateur '$username' a été ajouté au groupe '$groupname'." -ForegroundColor Green
        } else {
            Write-Host "[-] Échec de l'ajout : $result" -ForegroundColor Red
        }
    } else {
        $result = docker exec -i $ContainerName samba-tool group removemembers $groupname $username 2>&1
        if ($result -match "Removed members") {
            Write-Host "[+] L'utilisateur '$username' a été retiré du groupe '$groupname'." -ForegroundColor Green
        } else {
            Write-Host "[-] Échec du retrait : $result" -ForegroundColor Red
        }
    }
    Pause
}

# ---------------------------------------------------------
# MODULE PARTAGES
# ---------------------------------------------------------

function Add-SambaShare {
    Write-Host "`n[*] CRÉATION D'UN PARTAGE SAMBA" -ForegroundColor Yellow
    $shareName = Read-Host "Nom du partage (ex: Data)"
    $sharePath = Read-Host "Chemin absolu dans le conteneur (ex: /srv/samba/data)"
    
    if ([string]::IsNullOrWhiteSpace($shareName) -or [string]::IsNullOrWhiteSpace($sharePath)) { return }

    Write-Host "[*] Exécution dans le conteneur..." -ForegroundColor Cyan
    docker exec -i $ContainerName bash /cmd/manage_shares.sh add $shareName $sharePath
    Pause
}

function Remove-SambaShare {
    Write-Host "`n[*] SUPPRESSION D'UN PARTAGE SAMBA" -ForegroundColor Yellow
    $shareName = Read-Host "Nom du partage à supprimer"
    
    if ([string]::IsNullOrWhiteSpace($shareName)) { return }

    if ($shareName -match "^(sysvol|netlogon)$") {
        Write-Host "[!] Verrou de sécurité : Impossible de supprimer les partages vitaux de l'AD." -ForegroundColor Red
        Pause ; return
    }

    $confirm = Read-Host "Confirmer la suppression du partage '$shareName' ? (O/N)"
    if ($confirm -eq 'O' -or $confirm -eq 'o') {
        docker exec -i $ContainerName bash /cmd/manage_shares.sh remove $shareName
    }
    Pause
}

function Modify-SharePermissions {
    Write-Host "`n[*] MODIFICATION DES PERMISSIONS D'UN PARTAGE" -ForegroundColor Yellow
    $shareName = Read-Host "Nom du partage cible"
    $targetName = Read-Host "Nom de l'utilisateur ou du groupe (AD)"
    
    Write-Host "1. Lecture seule (rx)"
    Write-Host "2. Lecture / Écriture (rwx)"
    $permChoice = Read-Host "Choix de la permission (1 ou 2)"
    
    if ([string]::IsNullOrWhiteSpace($shareName) -or [string]::IsNullOrWhiteSpace($targetName)) { return }

    $permArg = if ($permChoice -eq '1') { "read" } elseif ($permChoice -eq '2') { "write" } else { $null }
    
    if ($null -eq $permArg) { 
        Write-Host "[-] Choix invalide." -ForegroundColor Red 
        Pause ; return 
    }

    docker exec -i $ContainerName bash /cmd/manage_shares.sh perms $shareName $targetName $permArg
    Pause
}

function Get-SambaShareList {
    Write-Host "`n[*] LISTE DES PARTAGES SAMBA" -ForegroundColor Yellow
    docker exec -i $ContainerName bash /cmd/manage_shares.sh list
    Pause
}

function Test-UserConnection {
    &./test.ps1
    Pause
}

# -----------------
# BOUCLE PRINCIPALE
# -----------------
do {
    Show-Menu
    $choice = Read-Host "-> Sélectionne une action (1-13)"

    switch ($choice) {
        '1' { Get-UserList }
        '2' { Add-SambaUser }
        '3' { Remove-SambaUser }
        '4' { Get-GroupList }
        '5' { Add-SambaGroup }
        '6' { Remove-SambaGroup }
        '7' { Manage-GroupMembers }
        '8' { Get-SambaShareList }
        '9' { Add-SambaShare }
        '10' { Remove-SambaShare }
        '11' { Modify-SharePermissions }
        '12' { Test-UserConnection }
        '13' { Write-Host "Fermeture de l'outil d'administration." -ForegroundColor Magenta ; break }
        default { Write-Host "Option invalide." -ForegroundColor Red ; Start-Sleep -Seconds 1 }
    }
} while ($choice -ne '13')