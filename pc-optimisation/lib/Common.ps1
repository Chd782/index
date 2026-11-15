# Common.ps1 - fonctions partagees par tous les scripts FPS Boost.
# ASCII uniquement (pas d'accents) pour rester compatible Windows PowerShell 5.1.
# Chaque modification est enregistree dans C:\ProgramData\FPSBoost\backup.json
# pour que 99_Restaurer.ps1 puisse tout remettre comme avant.

$ErrorActionPreference = 'Continue'
$global:FpsDir = Join-Path $env:ProgramData 'FPSBoost'
$global:FpsBackupFile = Join-Path $global:FpsDir 'backup.json'
$global:FpsBackup = New-Object System.Collections.ArrayList

function Write-Title { param([string]$Text) Write-Host ''; Write-Host "=== $Text ===" -ForegroundColor Cyan }
function Write-Ok    { param([string]$Text) Write-Host "  [OK] $Text" -ForegroundColor Green }
function Write-Info  { param([string]$Text) Write-Host "  [..] $Text" -ForegroundColor Gray }
function Write-Bad   { param([string]$Text) Write-Host "  [!!] $Text" -ForegroundColor Yellow }

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-Admin {
    if (-not (Test-Admin)) {
        Write-Bad 'Ce script doit etre lance en administrateur (utilise LANCER.bat).'
        Read-Host 'Entree pour quitter'
        exit 1
    }
}

function Ask-YesNo {
    param([string]$Question)
    $r = Read-Host "$Question (O/N)"
    return ($r -match '^[oOyY]')
}

function Import-Backup {
    $global:FpsBackup = New-Object System.Collections.ArrayList
    if (-not (Test-Path $global:FpsDir)) { New-Item -ItemType Directory -Path $global:FpsDir -Force | Out-Null }
    if (Test-Path $global:FpsBackupFile) {
        try {
            $json = Get-Content -Raw -Path $global:FpsBackupFile | ConvertFrom-Json
            foreach ($e in $json) { if ($null -ne $e) { [void]$global:FpsBackup.Add($e) } }
        } catch {
            Write-Bad "Sauvegarde illisible, elle est mise de cote : $($_.Exception.Message)"
            Copy-Item $global:FpsBackupFile "$($global:FpsBackupFile).corrompu" -Force
        }
    }
}

function Save-Backup {
    $arr = @($global:FpsBackup.ToArray())
    if ($arr.Count -eq 0) { $text = '[]' } else { $text = ConvertTo-Json -InputObject $arr -Depth 6 }
    Set-Content -Path $global:FpsBackupFile -Value $text -Encoding UTF8
}

function Test-BackupId {
    param([string]$Id)
    foreach ($e in $global:FpsBackup) { if ($e.Id -eq $Id) { return $true } }
    return $false
}

# N'enregistre que la PREMIERE valeur vue : c'est l'etat d'origine du PC.
function Add-BackupEntry {
    param([hashtable]$Entry)
    if (Test-BackupId $Entry.Id) { return }
    [void]$global:FpsBackup.Add([pscustomobject]$Entry)
    Save-Backup
}

function Set-Reg {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)]$Value,
        [string]$Type = 'DWord'
    )
    try {
        if (-not (Test-Path -LiteralPath $Path)) { New-Item -Path $Path -Force | Out-Null }
        $id = "reg|$Path|$Name"
        if (-not (Test-BackupId $id)) {
            $existed = $false; $old = $null; $oldType = $Type
            $key = Get-Item -LiteralPath $Path
            if ($key.GetValueNames() -contains $Name) {
                $existed = $true
                $old = $key.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                $oldType = $key.GetValueKind($Name).ToString()
            }
            Add-BackupEntry @{ Id = $id; Kind = 'reg'; Path = $Path; Name = $Name; Existed = $existed; Value = $old; Type = $oldType }
        }
        New-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
        Write-Ok "$Name = $Value"
    } catch {
        Write-Bad "Echec registre $Path\$Name : $($_.Exception.Message)"
    }
}

function Disable-Svc {
    param([string]$Name)
    $svc = Get-CimInstance -ClassName Win32_Service -Filter "Name='$Name'" -ErrorAction SilentlyContinue
    if (-not $svc) { Write-Info "Service $Name absent, ignore."; return }
    try {
        Add-BackupEntry @{ Id = "service|$Name"; Kind = 'service'; Name = $Name; StartMode = $svc.StartMode }
        Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
        Set-Service -Name $Name -StartupType Disabled -ErrorAction Stop
        Write-Ok "Service $Name desactive"
    } catch {
        Write-Bad "Echec service $Name : $($_.Exception.Message)"
    }
}

function Set-Nic {
    param([string]$Adapter, [string]$Keyword, [string]$Value)
    $prop = Get-NetAdapterAdvancedProperty -Name $Adapter -RegistryKeyword $Keyword -ErrorAction SilentlyContinue
    if (-not $prop) { return }
    $current = [string](@($prop.RegistryValue)[0])
    if ($current -eq $Value) { Write-Info "$Keyword deja a $Value"; return }
    if ($prop.ValidRegistryValues -and (@($prop.ValidRegistryValues) -notcontains $Value)) {
        Write-Info "$Keyword : valeur $Value non supportee par cette carte, ignore."
        return
    }
    try {
        Add-BackupEntry @{ Id = "nic|$Adapter|$Keyword"; Kind = 'nic'; Adapter = $Adapter; Keyword = $Keyword; Value = $current }
        Set-NetAdapterAdvancedProperty -Name $Adapter -RegistryKeyword $Keyword -RegistryValue $Value -ErrorAction Stop
        Write-Ok "$Adapter : $($prop.DisplayName) -> $Value"
    } catch {
        Write-Bad "Echec carte reseau $Keyword : $($_.Exception.Message)"
    }
}

function Get-ActivePowerPlan {
    $out = (powercfg /getactivescheme) -join ' '
    if ($out -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})') { return $Matches[1] }
    return $null
}

function New-RestorePoint {
    param([string]$Label)
    Write-Title 'Point de restauration Windows'
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction Stop
        Checkpoint-Computer -Description $Label -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop -WarningAction SilentlyContinue
        Write-Ok "Point de restauration demande : $Label"
        Write-Info '(Windows en cree un seul par 24 h : si un point recent existe deja, il sert de filet.)'
    } catch {
        Write-Bad "Point de restauration impossible : $($_.Exception.Message)"
        Write-Info 'Pas bloquant : 99_Restaurer.ps1 sait annuler chaque reglage un par un.'
    }
}
