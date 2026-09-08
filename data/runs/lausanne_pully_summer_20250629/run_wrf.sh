#!/bin/bash
set -euo pipefail
NP=${1:-14}
CASE=/data/runs/lausanne_pully_summer_20250629
cd "$CASE"

for f in /opt/WRF/run/*; do
  case "$f" in */namelist.input|*/namelist.wps) continue ;; esac
  [ -f "$f" ] && ln -sf "$f" .
done
ln -sf /opt/WRF/main/real.exe /opt/WRF/main/wrf.exe .

rm -f wrfinput_d0* wrfbdy_d01 wrfout_d0* rsl.* real.stdout wrf.stdout

echo "== real.exe (np=$NP) =="
mpirun --oversubscribe -np "$NP" ./real.exe > real.stdout 2>&1
grep -q "SUCCESS COMPLETE REAL" rsl.error.0000
ls wrfinput_d01 wrfinput_d02 wrfinput_d03 wrfinput_d04 wrfbdy_d01 > /dev/null

echo "== wrf.exe (np=$NP): 72 h de simulación =="
rm -f rsl.*
mpirun --oversubscribe -np "$NP" ./wrf.exe > wrf.stdout 2>&1
grep -q "SUCCESS COMPLETE WRF" rsl.error.0000

mkdir -p diagnostics
python3 ./extract_pblh_pully.py d03 46.5128 6.6591 2500 > diagnostics/pblh_extract_d03.log
python3 ./extract_pblh_pully.py d04 46.5128 6.6591 1000 > diagnostics/pblh_extract_d04.log

echo "WRF-OK: diagnósticos PBLH generados en $CASE/diagnostics"
