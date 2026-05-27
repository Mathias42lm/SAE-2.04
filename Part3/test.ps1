# Forcer l'encodage UTF-8 pour la console locale
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = 'Continue'
$ContainerName = "srv-ubuntu"

Write-Host "========================================" -ForegroundColor Magenta
Write-Host "   CAMPAGNE DE TESTS AUTOMATIQUES AD" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta

# Vérification que le conteneur est en ligne
$isRunning = (docker ps --format '{{.Names}}') -contains $ContainerName
if (-not $isRunning) {
    Write-Host "[!] ERREUR : Le conteneur $ContainerName n'est pas démarré." -ForegroundColor Red
    exit 1
}

function Invoke-SambaTest {
    param (
        [string]$Title,
        [string]$Share,
        [string]$User,
        [string]$Password,
        [string]$Command,
        [string]$ExpectedStatus # 'SUCCESS' ou 'DENIED'
    )

    Write-Host "[-] Test : $Title... " -NoNewline -ForegroundColor Cyan

    # Utilisation de docker exec sans -t pour éviter les caractères de contrôle TTY dans le flux
    $output = docker exec -i $ContainerName smbclient "//$ContainerName/$Share" -U "${User}%${Password}" -c $Command 2>&1

    $isDenied = $output -match "NT_STATUS_ACCESS_DENIED"
    $isRefused = $output -match "NT_STATUS_CONNECTION_REFUSED"

    if ($isRefused) {
        Write-Host "[ÉCHEC CRITIQUE]" -ForegroundColor Red
        Write-Host "    Le service Samba ne répond pas (Connexion refusée)." -ForegroundColor Red
        return
    }

    if ($ExpectedStatus -eq 'DENIED') {
        if ($isDenied) {
            Write-Host "[OK]" -ForegroundColor Green
        } else {
            Write-Host "[FAIL]" -ForegroundColor Red
            Write-Host "    L'accès aurait dû être refusé mais a été accepté ou a généré une autre erreur." -ForegroundColor Yellow
            Write-Host "    Détail : $output" -ForegroundColor DarkGray
        }
    } else {
        if ($isDenied) {
            Write-Host "[FAIL]" -ForegroundColor Red
            Write-Host "    L'accès légitime a été refusé (NT_STATUS_ACCESS_DENIED)." -ForegroundColor Yellow
        } elseif ($output -match "Error" -or $output -match "failed") {
            Write-Host "[FAIL]" -ForegroundColor Red
            Write-Host "    Une erreur est survenue lors de l'exécution." -ForegroundColor Yellow
            Write-Host "    Détail : $output" -ForegroundColor DarkGray
        } else {
            Write-Host "[OK]" -ForegroundColor Green
        }
    }
}

# ---------------------------------------------------------
# TEST 1 : Analyse statique de la configuration (testparm)
# ---------------------------------------------------------
Write-Host "`n[*] 1. Vérification de la syntaxe smb.conf (testparm)..." -ForegroundColor Cyan
$testparm = docker exec -i $ContainerName testparm -s 2>&1
if ($testparm -match "Loaded services file OK") {
    Write-Host "  -> [OK] Fichier de configuration valide." -ForegroundColor Green
} else {
    Write-Host "  -> [FAIL] Erreur détectée dans smb.conf." -ForegroundColor Red
    Write-Host "     $testparm" -ForegroundColor DarkGray
}

# ---------------------------------------------------------
# TEST 2 : Validation de la matrice des droits (ACL)
# ---------------------------------------------------------
Write-Host "`n[*] 2. Validation des accès réseaux et des ACL..." -ForegroundColor Cyan

# Étanchéité des partages privés
Invoke-SambaTest -Title "Accès exclusif de 'moi' sur 'amoi'" -Share "amoi" -User "moi" -Password "Root4242" -Command "ls" -ExpectedStatus "SUCCESS"
Invoke-SambaTest -Title "Refus d'accès de 'toi' sur 'amoi'" -Share "amoi" -User "toi" -Password "Root4242" -Command "ls" -ExpectedStatus "DENIED"
Invoke-SambaTest -Title "Refus d'accès de 'nous' sur 'amoi'" -Share "amoi" -User "nous" -Password "Root4242" -Command "ls" -ExpectedStatus "DENIED"

# Validation du répertoire public
Invoke-SambaTest -Title "Accès de 'nous' sur 'public' (Lecture)" -Share "public" -User "nous" -Password "Root4242" -Command "ls" -ExpectedStatus "SUCCESS"
Invoke-SambaTest -Title "Écriture de 'nous' dans 'public'" -Share "public" -User "nous" -Password "Root4242" -Command "mkdir test_nous; rm_dir test_nous" -ExpectedStatus "SUCCESS"

# Validation des droits asymétriques (Dossiers d'échange)
Invoke-SambaTest -Title "Accès et écriture de 'moi' sur 'amoi-atoi'" -Share "amoi-atoi" -User "moi" -Password "Root4242" -Command "mkdir test_moi; rm_dir test_moi" -ExpectedStatus "SUCCESS"
Invoke-SambaTest -Title "Accès en lecture seule de 'toi' sur 'amoi-atoi'" -Share "amoi-atoi" -User "toi" -Password "Root4242" -Command "ls" -ExpectedStatus "SUCCESS"
Invoke-SambaTest -Title "Interdiction d'écriture pour 'toi' sur 'amoi-atoi'" -Share "amoi-atoi" -User "toi" -Password "Root4242" -Command "mkdir tentative_toi" -ExpectedStatus "DENIED"

Write-Host "`n[+] Fin de la session de vérification." -ForegroundColor Magenta