$ErrorActionPreference = 'Stop'

# Nom du conteneur tel que défini dans ton docker-compose.yml
$ContainerName = "srv-ubuntu" 

Write-Host "========================================" -ForegroundColor Magenta
Write-Host "   LANCEMENT INFRASTRUCTURE AD SAMBA" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta

Write-Host "`n[*] 1. Nettoyage de l'ancien environnement..." -ForegroundColor Cyan
docker compose down -v

Write-Host "`n[*] 2. Construction et démarrage du conteneur..." -ForegroundColor Cyan
docker compose up -d --build

Write-Host "`n[*] Attente de l'initialisation du démon Samba (5 secondes)..." -ForegroundColor DarkGray
Start-Sleep -Seconds 5

# Vérification dynamique que le conteneur est bien UP
$isRunning = (docker ps --format '{{.Names}}') -contains $ContainerName
if (-not $isRunning) {
    Write-Host "`n[!] ERREUR : Le conteneur $ContainerName a crashé au démarrage." -ForegroundColor Red
    Write-Host "[!] Lance 'docker logs $ContainerName' pour voir l'erreur fatale." -ForegroundColor Red
    exit 1
}

Write-Host "`n[+] DÉPLOIEMENT TERMINÉ AVEC SUCCÈS !" -ForegroundColor Green