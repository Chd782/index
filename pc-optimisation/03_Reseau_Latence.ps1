# 03_Reseau_Latence.ps1 - reduit le delai reseau (pas les fps).
# ATTENTION : la connexion coupe 2 a 5 secondes pendant le reglage de la carte.
# Reversible avec 99_Restaurer.ps1.
. "$PSScriptRoot\lib\Common.ps1"
Assert-Admin
Import-Backup

$adapters = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' })
if ($adapters.Count -eq 0) {
    Write-Bad 'Aucune carte reseau active trouvee.'
    exit 0
}

foreach ($a in $adapters) {
    Write-Title "Carte : $($a.Name) ($($a.InterfaceDescription))"
    $isWifi = ($a.PhysicalMediaType -match '802\.11|Wireless|Wi-?Fi')

    # Nagle coupe : les petits paquets TCP partent tout de suite au lieu d'etre regroupes
    $tcp = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($a.InterfaceGuid)"
    Set-Reg $tcp 'TcpAckFrequency' 1
    Set-Reg $tcp 'TCPNoDelay' 1

    # Economies d'energie de la carte coupees
    Set-Nic $a.Name '*EEE' '0'
    Set-Nic $a.Name 'EnableGreenEthernet' '0'
    Set-Nic $a.Name 'AdvancedEEE' '0'
    Set-Nic $a.Name 'GigaLite' '0'
    Set-Nic $a.Name 'PowerSavingMode' '0'

    if ($isWifi) {
        Write-Bad 'Carte Wi-Fi : le cable Ethernet reste le plus gros gain de latence possible.'
    } else {
        Set-Nic $a.Name '*FlowControl' '0'
        # Chaque paquet est traite immediatement (un peu plus de CPU, moins de delai)
        Set-Nic $a.Name '*InterruptModeration' '0'
    }
}

Write-Title 'Pile TCP'
netsh int tcp set global autotuninglevel=normal | Out-Null
Write-Ok 'Auto-tuning TCP : normal'
netsh int tcp set global rss=enabled | Out-Null
Write-Ok 'Receive Side Scaling : actif'
ipconfig /flushdns | Out-Null
Write-Ok 'Cache DNS vide'

Write-Host ''
Write-Host 'Termine. Redemarre le PC pour appliquer les reglages TCP.' -ForegroundColor Cyan
