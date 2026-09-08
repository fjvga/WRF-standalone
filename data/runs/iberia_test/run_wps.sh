#!/bin/bash
# Ejecuta geogrid + ungrib + metgrid para el caso iberia_test
# Se ejecuta DENTRO del contenedor wrf-wps:4.7.1 con /data montado
set -euo pipefail
CASE=/data/runs/iberia_test
METDIR=/data/meteo/gfs_20260907_12z

cd "$CASE"

# Ejecutables y tablas de WPS
ln -sf /opt/WPS/geogrid.exe /opt/WPS/ungrib.exe /opt/WPS/metgrid.exe .
ln -sf /opt/WPS/ungrib/Variable_Tables/Vtable.GFS Vtable

# Limpieza de intentos previos
rm -f GRIBFILE.* FILE:* FILE.* met_em* geogrid.log ungrib.log metgrid.log \
      geo_em.d01.nc

echo "== geogrid =="
./geogrid.exe > geogrid.stdout 2>&1
grep -q "Successful completion" geogrid.log

echo "== ungrib (GFS 2026-09-07 12Z, f000-f036) =="
rm -f GRIBFILE.* ; /opt/WPS/link_grib.csh "$METDIR"/gfs.* > link_grib.out 2>&1
./ungrib.exe > ungrib.stdout 2>&1
grep -q "Successful completion" ungrib.log

echo "== metgrid =="
./metgrid.exe > metgrid.stdout 2>&1
grep -q "Successful completion" metgrid.log

N=$(ls met_em.d01.*.nc | wc -l)
echo "WPS-OK: $N ficheros met_em (esperados 9: 24 h a 3 h)"
[ "$N" -eq 9 ]
