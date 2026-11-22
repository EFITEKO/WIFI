# Diagnóstico WiFi para Windows (PowerShell)
# Uso: clic derecho > "Ejecutar con PowerShell", o:
#   powershell -ExecutionPolicy Bypass -File .\diagnostico-wifi.ps1
$ErrorActionPreference = 'SilentlyContinue'
$out = "$env:USERPROFILE\Desktop\informe-wifi.txt"
Start-Transcript -Path $out -Force | Out-Null

Write-Host "`n=== 1. CONEXION WIFI ===" -ForegroundColor Cyan
netsh wlan show interfaces | Select-String 'SSID|Estado|State|Se.al|Signal|Canal|Channel|Banda|Band|Radio|recepci|transmisi|Receive|Transmit'

Write-Host "`n=== 2. REDES CERCANAS (interferencia por canal) ===" -ForegroundColor Cyan
netsh wlan show networks mode=bssid | Select-String 'SSID|Se.al|Signal|Canal|Channel'

$cfg = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway } | Select-Object -First 1
$gw  = $cfg.IPv4DefaultGateway.NextHop
$ip  = $cfg.IPv4Address.IPAddress
Write-Host "`nMi IP: $ip   Router: $gw"

Write-Host "`n=== 3. LATENCIA ===" -ForegroundColor Cyan
foreach ($t in @($gw, '1.1.1.1', '8.8.8.8')) {
  $r = Test-Connection $t -Count 20 -ErrorAction SilentlyContinue
  $ok = @($r).Count
  $avg = if ($ok) { [math]::Round(($r | Measure-Object -Property ResponseTime -Average).Average,1) } else { 'n/a' }
  $max = if ($ok) { ($r | Measure-Object -Property ResponseTime -Maximum).Maximum } else { 'n/a' }
  Write-Host ("{0,-15} media {1} ms  max {2} ms  perdidos {3}/20" -f $t, $avg, $max, (20-$ok))
}

Write-Host "`n=== 4. DISPOSITIVOS CONECTADOS ===" -ForegroundColor Cyan
$prefix = ($ip -split '\.')[0..2] -join '.'
Write-Host "Escaneando $prefix.1-254 (unos 30 s)..."
$jobs = 1..254 | ForEach-Object { $p = New-Object System.Net.NetworkInformation.Ping; @{ ip="$prefix.$_"; t=$p.SendPingAsync("$prefix.$_", 500) } }
$jobs | ForEach-Object { try { $_.t.Wait() } catch {} }
Get-NetNeighbor -AddressFamily IPv4 | Where-Object { $_.IPAddress -like "$prefix.*" -and $_.State -ne 'Unreachable' -and $_.LinkLayerAddress -ne '00-00-00-00-00-00' -and $_.LinkLayerAddress -ne 'FF-FF-FF-FF-FF-FF' } |
  Sort-Object { [version]$_.IPAddress } | ForEach-Object {
    $name = try { [System.Net.Dns]::GetHostEntry($_.IPAddress).HostName } catch { '?' }
    "{0,-16} {1,-18} {2}" -f $_.IPAddress, $_.LinkLayerAddress, $name
  } | Tee-Object -Variable devs
Write-Host "Total: $(@($devs).Count) dispositivos"

Write-Host "`n=== 5. VELOCIDAD DE DESCARGA ===" -ForegroundColor Cyan
$sw = [Diagnostics.Stopwatch]::StartNew()
$bytes = (Invoke-WebRequest 'https://speed.cloudflare.com/__down?bytes=50000000' -UseBasicParsing).RawContentLength
$sw.Stop()
Write-Host ("Descarga: {0:N1} Mbps" -f (($bytes*8/1e6)/$sw.Elapsed.TotalSeconds))

Stop-Transcript | Out-Null
Write-Host "`nInforme guardado en: $out" -ForegroundColor Green
Read-Host "Pulsa Enter para cerrar"
