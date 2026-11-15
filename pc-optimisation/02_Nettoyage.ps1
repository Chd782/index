# 02_Nettoyage.ps1 - allege Windows : fichiers temporaires, telemetrie, applis en fond.
# Reversible avec 99_Restaurer.ps1 (sauf les fichiers temporaires supprimes, sans valeur).
. "$PSScriptRoot\lib\Common.ps1"
Assert-Admin
Import-Backup

function Clear-Folder {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $before = (Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    $after = (Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    Write-Ok ("{0} : {1} Mo liberes" -f $Path, [math]::Round((($before - $after) / 1MB)))
}

Write-Title 'Fichiers temporaires'
Clear-Folder $env:TEMP
Clear-Folder (Join-Path $env:SystemRoot 'Temp')

Write-Title 'OPTIONNEL : caches de shaders'
Write-Info 'Utile apres une mise a jour du pilote NVIDIA ou si un jeu saccade bizarrement.'
Write-Info 'Les jeux les recompilent au lancement suivant (premier lancement plus long).'
if (Ask-YesNo '  Vider les caches de shaders ?') {
    Clear-Folder (Join-Path $env:LOCALAPPDATA 'NVIDIA\DXCache')
    Clear-Folder (Join-Path $env:LOCALAPPDATA 'NVIDIA\GLCache')
    Clear-Folder (Join-Path $env:LOCALAPPDATA 'D3DSCache')
} else {
    Write-Info 'Caches conserves.'
}

Write-Title 'Telemetrie Windows'
Disable-Svc 'DiagTrack'
Disable-Svc 'dmwappushservice'
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 0

Write-Title 'Applis en arriere-plan et installations automatiques'
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' 'GlobalUserDisabled' 1
$cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
Set-Reg $cdm 'SilentInstalledAppsEnabled' 0
Set-Reg $cdm 'PreInstalledAppsEnabled' 0
Set-Reg $cdm 'SystemPaneSuggestionsEnabled' 0

Write-Title 'Programmes lances au demarrage (a couper toi-meme)'
$startup = @(Get-CimInstance Win32_StartupCommand)
if ($startup.Count -eq 0) { Write-Info 'Aucun.' }
foreach ($s in $startup) { Write-Info $s.Name }
Write-Host ''
Write-Host '  Ctrl+Maj+Echap > onglet Demarrage : desactive tout ce qui ne sert pas en jeu' -ForegroundColor Yellow
Write-Host '  (launchers, Discord auto, Spotify, logiciels RGB en double, updaters...).' -ForegroundColor Yellow
Write-Host '  Garde : pilote audio, logiciel souris/clavier si tu utilises ses profils.' -ForegroundColor Yellow

Write-Host ''
Write-Host 'Termine.' -ForegroundColor Cyan
