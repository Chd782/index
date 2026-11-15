# 01_Windows_Gaming.ps1 - reglages Windows qui comptent vraiment pour les fps et la latence.
# Tout est reversible avec 99_Restaurer.ps1.
. "$PSScriptRoot\lib\Common.ps1"
Assert-Admin
Import-Backup
New-RestorePoint 'FPS Boost - avant optimisation'

# ---------------------------------------------------------------------------
Write-Title 'Mode alimentation Performances optimales'
$fpsPlan = 'f1b0057e-0000-4000-8000-5800c3060200'
$ultimate = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
$current = Get-ActivePowerPlan
if ($current -and ($current -ne $fpsPlan)) {
    Add-BackupEntry @{ Id = 'powerplan'; Kind = 'powerplan'; Guid = $current }
}
$list = (powercfg /list) -join ' '
if ($list -notmatch $fpsPlan) {
    powercfg -duplicatescheme $ultimate $fpsPlan | Out-Null
    powercfg -changename $fpsPlan 'FPS Boost' 'Performances optimales pour le jeu' | Out-Null
}
$list = (powercfg /list) -join ' '
if ($list -match $fpsPlan) {
    # USB : pas de mise en veille selective (souris / clavier toujours reactifs)
    powercfg -setacvalueindex $fpsPlan 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 | Out-Null
    # PCI Express : pas d'economie d'energie sur le lien du GPU
    powercfg -setacvalueindex $fpsPlan 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0 | Out-Null
    # Disque : jamais d'arret
    powercfg -setacvalueindex $fpsPlan 0012ee47-9041-4b5d-9b77-535fba8b1442 6738e2c4-e8a5-4a42-b16a-e040e769756e 0 | Out-Null
    powercfg -setactive $fpsPlan | Out-Null
    Write-Ok 'Mode FPS Boost actif (coeurs jamais parques, USB et PCIe sans veille)'
} else {
    Write-Bad 'Impossible de creer le mode FPS Boost, bascule sur Performances elevees.'
    powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c | Out-Null
}

# ---------------------------------------------------------------------------
Write-Title 'Mode Jeu actif, enregistrement en arriere-plan coupe'
Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1
Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' 1
Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'HistoricalCaptureEnabled' 0

# ---------------------------------------------------------------------------
Write-Title 'GPU : planification acceleree (HAGS) + optimisation des jeux fenetres'
Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 2
# Fusionne avec les reglages existants (VRR, etc.) au lieu de les ecraser
$dxPath = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
$dxOld = ''
try { $dxOld = [string](Get-ItemProperty -LiteralPath $dxPath -Name 'DirectXUserGlobalSettings' -ErrorAction Stop).DirectXUserGlobalSettings } catch { }
$parts = @($dxOld -split ';' | Where-Object { $_ -and ($_ -notmatch '^SwapEffectUpgradeEnable=') })
$parts += 'SwapEffectUpgradeEnable=1'
Set-Reg $dxPath 'DirectXUserGlobalSettings' (($parts -join ';') + ';') 'String'

# ---------------------------------------------------------------------------
Write-Title 'Souris : acceleration desactivee (visee 1:1)'
Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseSpeed' '0' 'String'
Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold1' '0' 'String'
Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold2' '0' 'String'

# ---------------------------------------------------------------------------
Write-Title 'Priorite CPU au jeu au premier plan'
# 20 % du CPU reserve aux taches de fond par defaut -> 10 %
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' 'SystemResponsiveness' 10
# Windows ne bride plus les processus pour economiser l'energie
Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff' 1

# ---------------------------------------------------------------------------
Write-Title 'Divers'
# Demarrage rapide coupe : chaque allumage est un vrai demarrage propre
Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'HiberbootEnabled' 0
# Transparence de l'interface coupee (un peu de GPU en moins pour le bureau)
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 0

# ---------------------------------------------------------------------------
Write-Title 'OPTIONNEL : integrite de la memoire (Core Isolation)'
$hvciPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity'
$hvci = $null
try { $hvci = (Get-ItemProperty -LiteralPath $hvciPath -Name 'Enabled' -ErrorAction Stop).Enabled } catch { }
if ($hvci -eq 1) {
    Write-Info "Elle est ACTIVE. La couper rapporte environ 5 a 10 % de fps, mais c'est une"
    Write-Info 'protection de securite de Windows contre les pilotes malveillants.'
    Write-Info 'A ne faire que sur un PC de jeu ou tu installes des logiciels de confiance.'
    if (Ask-YesNo '  La desactiver ?') {
        Set-Reg $hvciPath 'Enabled' 0
    } else {
        Write-Info 'Laissee active.'
    }
} else {
    Write-Info 'Deja desactivee, rien a faire.'
}

Write-Host ''
Write-Host 'Termine. REDEMARRE le PC pour appliquer HAGS, la souris et le reste.' -ForegroundColor Cyan
