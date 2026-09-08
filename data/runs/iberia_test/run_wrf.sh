#!/bin/bash
# Ejecuta real.exe + wrf.exe para el caso iberia_test
# Se ejecuta DENTRO del contenedor wrf-wps:4.7.1 con /data montado
# Uso: run_wrf.sh [nproc]
set -euo pipefail
NP=${1:-14}
CASE=/data/runs/iberia_test
cd "$CASE"

# Tablas de física de WRF (LANDUSE.TBL, VEGPARM.TBL, ...) desde el run oficial
# (nunca enlazar namelist.input/namelist.wps: pisaría la configuración del caso)
for f in /opt/WRF/run/*; do
  case "$f" in */namelist.input|*/namelist.wps) continue ;; esac
  [ -f "$f" ] && ln -sf "$f" .
done
ln -sf /opt/WRF/main/real.exe /opt/WRF/main/wrf.exe .

echo "== real.exe (np=$NP) =="
mpirun --oversubscribe -np "$NP" ./real.exe > real.stdout 2>&1
grep -q "SUCCESS COMPLETE REAL" rsl.error.0000
ls wrfinput_d01 wrfbdy_d01 > /dev/null

echo "== wrf.exe (np=$NP): 24 h de simulación =="
rm -f wrfout_d01_* rsl.* wrf.out
mpirun --oversubscribe -np "$NP" ./wrf.exe > wrf.stdout 2>&1
grep -q "SUCCESS COMPLETE WRF" rsl.error.0000

N=$(ls wrfout_d01_* | wc -l)
echo "WRF-OK: $N wrfout (esperados 9: 24 h cada 3 h)"
[ "$N" -eq 9 ]
