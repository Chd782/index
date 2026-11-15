# 99_Restaurer.ps1 - annule TOUT ce que les scripts 01, 02 et 03 ont modifie,
# en relisant C:\ProgramData\FPSBoost\backup.json (valeurs d'origine du PC).
. "$PSScriptRoot\lib\Common.ps1"
Assert-Admin
Import-Backup

if ($global:FpsBackup.Count -eq 0) {
    Write-Info 'Aucune modification enregistree : rien a restaurer.'
    exit 0
}

Write-Host "$($global:FpsBackup.Count) reglage(s) a remettre comme avant." -ForegroundColor Cyan
if (-not (Ask-YesNo 'Continuer ?')) { exit 0 }

$failed = New-Object System.Collections.ArrayList
$entries = @($global:FpsBackup.ToArray())
[array]::Reverse($entries)

foreach ($e in $entries) {
    try {
        switch ($e.Kind) {
            'reg' {
                if ($e.Existed) {
                    $v = $e.Value
                    switch ($e.Type) {
                        'Binary'      { $v = [byte[]]@($e.Value) }
                        'MultiString' { $v = [string[]]@($e.Value) }
                        'DWord'       { $v = [int]$e.Value }
                        'QWord'       { $v = [long]$e.Value }
                        default       { $v = [string]$e.Value }
                    }
                    if (-not (Test-Path -LiteralPath $e.Path)) { New-Item -Path $e.Path -Force | Out-Null }
                    New-ItemProperty -LiteralPath $e.Path -Name $e.Name -Value $v -PropertyType $e.Type -Force -ErrorAction Stop | Out-Null
                    Write-Ok "$($e.Name) remis a $($e.Value)"
                } else {
                    if (Test-Path -LiteralPath $e.Path) {
                        Remove-ItemProperty -LiteralPath $e.Path -Name $e.Name -Force -ErrorAction SilentlyContinue
                    }
                    Write-Ok "$($e.Name) supprime (n'existait pas avant)"
                }
            }
            'service' {
                $mode = switch ($e.StartMode) { 'Auto' { 'Automatic' } 'Manual' { 'Manual' } 'Disabled' { 'Disabled' } default { 'Manual' } }
                Set-Service -Name $e.Name -StartupType $mode -ErrorAction Stop
                if ($mode -eq 'Automatic') { Start-Service -Name $e.Name -ErrorAction SilentlyContinue }
                Write-Ok "Service $($e.Name) remis en $mode"
            }
            'nic' {
                Set-NetAdapterAdvancedProperty -Name $e.Adapter -RegistryKeyword $e.Keyword -RegistryValue $e.Value -ErrorAction Stop
                Write-Ok "$($e.Adapter) : $($e.Keyword) remis a $($e.Value)"
            }
            'powerplan' {
                powercfg -setactive $e.Guid | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "powercfg a refuse le mode $($e.Guid)" }
                powercfg -delete 'f1b0057e-0000-4000-8000-5800c3060200' 2>$null | Out-Null
                Write-Ok "Mode d'alimentation d'origine reactive"
            }
            default { throw "type inconnu : $($e.Kind)" }
        }
    } catch {
        Write-Bad "Echec pour $($e.Id) : $($_.Exception.Message)"
        [void]$failed.Add($e)
    }
}

# On ne garde dans la sauvegarde que ce qui n'a pas pu etre restaure
$global:FpsBackup = New-Object System.Collections.ArrayList
foreach ($f in $failed) { [void]$global:FpsBackup.Add($f) }
Save-Backup

Write-Host ''
if ($failed.Count -eq 0) {
    Write-Host 'Tout est restaure. Redemarre le PC.' -ForegroundColor Cyan
} else {
    Write-Host "$($failed.Count) reglage(s) non restaure(s), relance ce script apres redemarrage." -ForegroundColor Yellow
}
