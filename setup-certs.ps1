# setup-certs.ps1
param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectName,
    
    [Parameter(Mandatory=$true)]
    [string]$Domains
)

# Vérifier les droits admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Ce script nécessite des droits administrateur" -ForegroundColor Red
    Exit
}

# Fonction pour générer la configuration Traefik pour un service
function Get-TraefikConfig {
    param(
        [string]$Domain,
        [string]$ServiceName
    )
    return @"
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.$ServiceName.rule=Host(\`"$Domain\`")"
      - "traefik.http.routers.$ServiceName.tls=true"
      - "traefik.http.services.$ServiceName.loadbalancer.server.port=80"
"@
}

# Fonction pour nettoyer le contenu du fichier hosts
function Clean-HostsContent {
    param(
        [string[]]$Content
    )
    
    $cleanedContent = @()
    
    foreach ($line in $Content) {
        # Ignorer les lignes vides ou commentaires
        if ([string]::IsNullOrWhiteSpace($line) -or $line.TrimStart().StartsWith('#')) {
            $cleanedContent += $line
            continue
        }

        # Séparer les entrées multiples sur une même ligne
        $entries = $line -split '127\.0\.0\.1' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        
        foreach ($entry in $entries) {
            # Extraire le commentaire si présent
            $comment = ""
            if ($entry -match '#') {
                $parts = $entry -split '#'
                $entry = $parts[0]
                $comment = "#" + ($parts[1..($parts.Length-1)] -join '#')
            }

            # Nettoyer l'entrée
            $domain = $entry.Trim()
            if (-not [string]::IsNullOrWhiteSpace($domain)) {
                if ([string]::IsNullOrWhiteSpace($comment)) {
                    $cleanedContent += "127.0.0.1      $domain"
                } else {
                    $cleanedContent += "127.0.0.1      $domain $comment"
                }
            }
        }
    }
    
    return $cleanedContent
}

# Fonction pour récupérer les domaines existants d'un projet
function Get-ExistingProjectDomains {
    param(
        [string]$ProjectName,
        [string]$HostsFile
    )
    
    $hostContent = Get-Content $HostsFile
    $pattern = "127\.0\.0\.1\s+([^.\s]+)\.$ProjectName\.2nm"
    $existingDomains = @()
    
    foreach ($line in $hostContent) {
        if ($line -match $pattern) {
            $existingDomains += $matches[1]
        }
    }
    
    return $existingDomains
}

# Fonction de mise à jour du fichier hosts
function Update-HostsFile {
    param(
        [string[]]$NewDomains,
        [string]$ProjectName
    )
    
    $hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
    
    # Récupérer et nettoyer le contenu actuel
    $hostContent = Get-Content $hostsFile
    $hostContent = Clean-HostsContent -Content $hostContent
    
    # Récupérer les domaines existants du projet
    $existingDomains = Get-ExistingProjectDomains -ProjectName $ProjectName -HostsFile $hostsFile
    
    if ($existingDomains.Count -gt 0) {
        Write-Host "`nDomaines existants pour le projet $ProjectName :" -ForegroundColor Yellow
        $existingDomains | ForEach-Object { Write-Host "- $_.$ProjectName.2nm" -ForegroundColor Gray }
    }

    # Identifier les nouveaux domaines
    $domainsToAdd = $NewDomains | Where-Object { $_ -notin $existingDomains }
    
    # Créer une sauvegarde
    $backupFile = "$env:SystemRoot\System32\drivers\etc\hosts.backup"
    $hostContent | Set-Content -Path $backupFile -Force
    Write-Host "Sauvegarde du fichier hosts créée: $backupFile" -ForegroundColor Yellow
    
    try {
        if ($domainsToAdd.Count -gt 0) {
            Write-Host "`nAjout des nouveaux domaines :" -ForegroundColor Green
            
            # Préparer toutes les nouvelles entrées
            $newEntries = @()
            foreach ($domain in $domainsToAdd) {
                $fullDomain = "$domain.$ProjectName.2nm"
                $newEntries += "127.0.0.1      $fullDomain"
                Write-Host "+ $fullDomain" -ForegroundColor Green
            }

            # Écrire tout le contenu d'un coup
            $updatedContent = $hostContent + $newEntries
            $updatedContent | Set-Content -Path $hostsFile -Force
        } else {
            Write-Host "`nAucun nouveau domaine à ajouter." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Erreur lors de la mise à jour du fichier hosts. Restauration..." -ForegroundColor Red
        Get-Content $backupFile | Set-Content -Path $hostsFile -Force
        throw
    }

    # Retourner la liste complète des domaines
    return (@($existingDomains) + @($NewDomains) | Select-Object -Unique)
}

# Convertir la chaîne de domaines en tableau
$domainList = $Domains.Split(',') | ForEach-Object { $_.Trim() }

Write-Host "Configuration pour le projet: $ProjectName" -ForegroundColor Blue
Write-Host "Nouveaux domaines à configurer:" -ForegroundColor Blue
$domainList | ForEach-Object { Write-Host "- $_.$ProjectName.2nm" -ForegroundColor Gray }

# Mettre à jour le fichier hosts et récupérer tous les domaines (existants + nouveaux)
$allDomains = Update-HostsFile -NewDomains $domainList -ProjectName $ProjectName

# Créer le dossier pour les certificats
$certsPath = ".\certs"
if (-not (Test-Path $certsPath)) {
    New-Item -ItemType Directory -Path $certsPath -Force | Out-Null
    Write-Host "Dossier des certificats créé: $certsPath" -ForegroundColor Green
}

# Préparer les domaines complets pour mkcert
$certDomains = @()
foreach ($domain in $allDomains) {
    $certDomains += "$domain.$ProjectName.2nm"
}
$certDomains += "traefik.2nm"

# Installer le CA root de mkcert
Write-Host "`nInstallation du certificat root mkcert..." -ForegroundColor Yellow
mkcert -install

# Générer les certificats
Write-Host "`nGénération des certificats SSL..." -ForegroundColor Yellow
Write-Host "Domaines inclus dans le certificat :" -ForegroundColor Cyan
$certDomains | ForEach-Object { Write-Host "- $_" -ForegroundColor Cyan }

Push-Location $certsPath
$mkcertArgs = @("-cert-file", "local-cert.pem", "-key-file", "local-key.pem")
$mkcertArgs += $certDomains
& mkcert $mkcertArgs
Pop-Location

# Vérifier si les certificats ont été créés
if (-not (Test-Path ".\certs\local-cert.pem") -or -not (Test-Path ".\certs\local-key.pem")) {
    Write-Host "`nErreur : Les certificats n'ont pas été créés correctement" -ForegroundColor Red
    Exit
}

Write-Host "`nConfiguration terminée !" -ForegroundColor Green
Write-Host "Certificats générés dans : $((Get-Item $certsPath).FullName)" -ForegroundColor Green
Write-Host "- local-cert.pem"
Write-Host "- local-key.pem"

Write-Host "`nURLs disponibles :" -ForegroundColor Green
$certDomains | ForEach-Object {
    Write-Host "https://$_" -ForegroundColor Cyan
}

Write-Host "`nConfigurations Traefik pour les services :" -ForegroundColor Yellow
foreach ($domain in $domainList) {
    $fullDomain = "$domain.$ProjectName.2nm"
    Write-Host "`nPour le domaine $fullDomain :" -ForegroundColor Cyan
    Write-Host (Get-TraefikConfig -Domain $fullDomain -ServiceName $domain.ToLower()) -ForegroundColor Green
}