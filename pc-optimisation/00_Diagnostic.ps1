# 00_Diagnostic.ps1 - LECTURE SEULE. Ne modifie rien.
# Genere un rapport sur le Bureau (FPSBoost_Diagnostic.txt) a lancer AVANT et APRES.
. "$PSScriptRoot\lib\Common.ps1"

$lines = New-Object System.Collections.ArrayList
$warn = New-Object System.Collections.ArrayList
function Out-L { param([string]$t = '') [void]$lines.Add($t); Write-Host $t }
function Out-W { param([string]$t) [void]$warn.Add($t) }
function Get-RegValue {
    param([string]$Path, [string]$Name)
    try { return (Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction Stop).$Name } catch { return $null }
}

Out-L "FPS BOOST - DIAGNOSTIC - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
Out-L ('-' * 60)

# --- Systeme ---
$os = Get-CimInstance Win32_OperatingSystem
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$bb = Get-CimInstance Win32_BaseBoard
$bios = Get-CimInstance Win32_BIOS
Out-L "Windows      : $($os.Caption) build $($os.BuildNumber)"
Out-L "CPU          : $($cpu.Name.Trim()) ($($cpu.NumberOfCores) coeurs / $($cpu.NumberOfLogicalProcessors) threads)"
Out-L "Carte mere   : $($bb.Manufacturer) $($bb.Product)"
Out-L "BIOS         : $($bios.SMBIOSBIOSVersion) du $($bios.ReleaseDate.ToString('yyyy-MM-dd'))"
if ($bios.ReleaseDate -lt (Get-Date '2023-01-01')) { Out-W 'BIOS ancien (avant 2023) : une mise a jour apporte AGESA recent (stabilite PBO, correctif stutter fTPM).' }

# --- RAM ---
Out-L ''
Out-L 'RAM :'
$mem = @(Get-CimInstance Win32_PhysicalMemory)
$totalGb = [math]::Round((($mem | Measure-Object Capacity -Sum).Sum) / 1GB)
foreach ($m in $mem) {
    Out-L ("  {0,-12} {1,3} Go  nominal {2} MHz  actuel {3} MHz  {4}" -f $m.DeviceLocator, [math]::Round($m.Capacity / 1GB), $m.Speed, $m.ConfiguredClockSpeed, ([string]$m.PartNumber).Trim())
}
Out-L "  Total : $totalGb Go en $($mem.Count) barrette(s)"
$cfg = ($mem | Measure-Object ConfiguredClockSpeed -Minimum).Minimum
if ($cfg -and $cfg -le 2800) { Out-W "RAM a $cfg MHz : XMP (A-XMP) n'est surement PAS active dans le BIOS. C'est le plus gros gain possible sur un 5800X (souvent +15 a 30 % de fps mini)." }
if ($mem.Count -eq 1) { Out-W 'Une seule barrette = single channel. Il faut 2 barrettes (slots A2 + B2) pour le dual channel.' }
if ($totalGb -lt 16) { Out-W 'Moins de 16 Go de RAM : limite pour les jeux recents.' }

# --- GPU / ecran ---
Out-L ''
Out-L 'GPU / ecran :'
foreach ($g in @(Get-CimInstance Win32_VideoController)) {
    Out-L "  $($g.Name)  pilote $($g.DriverVersion) du $(if ($g.DriverDate) { $g.DriverDate.ToString('yyyy-MM-dd') })"
    if ($g.CurrentRefreshRate) {
        Out-L "  Affichage : $($g.CurrentHorizontalResolution)x$($g.CurrentVerticalResolution) a $($g.CurrentRefreshRate) Hz"
        if ($g.CurrentRefreshRate -le 60) { Out-W "Ecran regle sur $($g.CurrentRefreshRate) Hz. Si ton ecran fait 144/165/240 Hz, regle-le dans Parametres > Affichage > Affichage avance (et utilise un cable DisplayPort)." }
    }
}
$smi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
if ($smi) {
    $q = & nvidia-smi --query-gpu=name,driver_version,temperature.gpu,pcie.link.gen.current,pcie.link.width.current,memory.total --format=csv,noheader 2>$null
    Out-L "  nvidia-smi (nom, pilote, temp, PCIe gen, PCIe largeur, VRAM) : $q"
    if ($q -match ',\s*(\d+)\s*,\s*\d+ MiB') { if ([int]$Matches[1] -lt 16) { Out-W "GPU en PCIe x$($Matches[1]) au lieu de x16 : verifie qu'il est dans le slot du haut (PCI_E1)." } }
} else {
    Out-L '  nvidia-smi introuvable (pilote NVIDIA absent ou ancien ?)'
}

# --- Reglages Windows ---
Out-L ''
Out-L 'Reglages Windows :'
$plan = (powercfg /getactivescheme) -join ' '
Out-L "  Mode alimentation : $plan"
$gm = Get-RegValue 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled'
Out-L "  Mode Jeu          : $(if ($gm -eq 0) { 'DESACTIVE' } else { 'actif (ou defaut)' })"
$dvr = Get-RegValue 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled'
Out-L "  Game DVR (enreg.) : $(if ($dvr -eq 0) { 'desactive' } else { 'ACTIF' })"
$hags = Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode'
Out-L "  HAGS (planif. GPU): $(if ($hags -eq 2) { 'actif' } else { 'desactive' })"
$ms = Get-RegValue 'HKCU:\Control Panel\Mouse' 'MouseSpeed'
Out-L "  Accel. souris     : $(if ("$ms" -eq '0') { 'desactivee' } else { 'ACTIVE' })"
try {
    $dg = Get-CimInstance -Namespace 'root\Microsoft\Windows\DeviceGuard' -ClassName Win32_DeviceGuard -ErrorAction Stop
    $vbs = switch ($dg.VirtualizationBasedSecurityStatus) { 0 { 'desactive' } 1 { 'active mais pas en cours' } 2 { 'EN COURS' } default { '?' } }
    Out-L "  VBS               : $vbs"
    $hvci = Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' 'Enabled'
    Out-L "  Integrite memoire : $(if ($hvci -eq 1) { 'ACTIVE (coute environ 5 a 10 % de fps)' } else { 'desactivee' })"
} catch { Out-L '  VBS               : inconnu' }

# --- Stockage ---
Out-L ''
Out-L 'Stockage :'
try {
    foreach ($d in @(Get-PhysicalDisk)) { Out-L "  $($d.FriendlyName)  $($d.MediaType)  $([math]::Round($d.Size / 1GB)) Go  sante: $($d.HealthStatus)" }
} catch { Out-L '  (Get-PhysicalDisk indisponible)' }
foreach ($v in @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3')) {
    $pct = if ($v.Size) { [math]::Round(100 * $v.FreeSpace / $v.Size) } else { 0 }
    Out-L "  $($v.DeviceID) libre $([math]::Round($v.FreeSpace / 1GB)) Go ($pct %)"
    if ($pct -lt 10) { Out-W "Disque $($v.DeviceID) presque plein ($pct % libre) : garde au moins 15 % libre." }
}

# --- Demarrage / processus ---
Out-L ''
Out-L 'Programmes au demarrage :'
foreach ($s in @(Get-CimInstance Win32_StartupCommand)) { Out-L "  $($s.Name)" }
Out-L ''
Out-L 'Top 10 processus par RAM :'
foreach ($p in @(Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 10)) {
    Out-L ("  {0,-30} {1,6} Mo" -f $p.ProcessName, [math]::Round($p.WorkingSet64 / 1MB))
}

# --- Reseau ---
Out-L ''
Out-L 'Reseau :'
try {
    foreach ($a in @(Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' })) {
        Out-L "  $($a.Name) : $($a.InterfaceDescription) - $($a.LinkSpeed)"
        if ($a.PhysicalMediaType -match '802\.11|Wireless|Wi-?Fi') { Out-W 'Tu joues en Wi-Fi : un cable Ethernet reduit plus le delai que tous les tweaks reseau reunis.' }
    }
} catch { Out-L '  (Get-NetAdapter indisponible)' }

# --- Bilan ---
Out-L ''
Out-L ('-' * 60)
Out-L 'POINTS A CORRIGER :'
if ($warn.Count -eq 0) { Out-L '  Rien de bloquant detecte.' } else { foreach ($w in $warn) { Out-L "  * $w" } }

$dest = Join-Path ([Environment]::GetFolderPath('Desktop')) 'FPSBoost_Diagnostic.txt'
Set-Content -Path $dest -Value $lines -Encoding UTF8
Write-Host ''
Write-Host "Rapport enregistre : $dest" -ForegroundColor Cyan
Write-Host 'Copie-colle ce fichier a Claude pour un reglage sur mesure.' -ForegroundColor Cyan
