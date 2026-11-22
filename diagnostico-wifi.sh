#!/usr/bin/env bash
# Diagnóstico WiFi para macOS / Linux.  Uso: bash diagnostico-wifi.sh | tee informe-wifi.txt
OS=$(uname)
echo "=== 1. CONEXION WIFI ==="
if [ "$OS" = Darwin ]; then
  system_profiler SPAirPortDataType 2>/dev/null | sed -n '/Current Network Information/,/Other Local/p' | head -20
  GW=$(route -n get default | awk '/gateway/{print $2}')
else
  (iw dev 2>/dev/null | awk '/Interface/{print $2}' | while read i; do iw dev "$i" link; done) || nmcli dev wifi list
  GW=$(ip route | awk '/default/{print $3; exit}')
fi
echo; echo "Router: $GW"

echo; echo "=== 2. LATENCIA ==="
for t in "$GW" 1.1.1.1 8.8.8.8; do
  echo "--- $t"; ping -c 20 -i 0.3 "$t" 2>/dev/null | tail -2
done

echo; echo "=== 3. DISPOSITIVOS CONECTADOS ==="
P=${GW%.*}
for i in $(seq 1 254); do ping -c1 -W1 "$P.$i" >/dev/null 2>&1 & done; wait
arp -a | grep -v incomplete | grep "$P\."
echo "Total: $(arp -a | grep -v incomplete | grep -c "$P\.")"

echo; echo "=== 4. VELOCIDAD DE DESCARGA ==="
curl -s -o /dev/null -w '%{speed_download}\n' 'https://speed.cloudflare.com/__down?bytes=50000000' |
  awk '{printf "Descarga: %.1f Mbps\n", $1*8/1e6}'
