# 2. setup-traefik-network.ps1 (Pour Docker uniquement)
param(
    [Parameter(Mandatory=$false)]
    [string]$NetworkName = "traefik-public"
)

try {
    $networkExists = docker network ls --format '{{.Name}}' | Select-String -Pattern "^$NetworkName`$"
    if (-not $networkExists) {
        docker network create $NetworkName
        Write-Host "Réseau $NetworkName créé" -ForegroundColor Green
    } else {
        Write-Host "Le réseau $NetworkName existe déjà" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "Erreur lors de la création du réseau Docker: $_" -ForegroundColor Red
    Write-Host "Assurez-vous que Docker est démarré" -ForegroundColor Yellow
}