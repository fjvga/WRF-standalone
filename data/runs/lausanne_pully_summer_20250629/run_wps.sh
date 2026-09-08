#!/bin/bash
set -euo pipefail
CASE=/data/runs/lausanne_pully_summer_20250629
METDIR=/data/meteo/gfs_20250626_00z

cd "$CASE"

ln -sf /opt/WPS/geogrid.exe /opt/WPS/ungrib.exe /opt/WPS/metgrid.exe .
ln -sf /opt/WPS/ungrib/Variable_Tables/Vtable.GFS Vtable
ln -sf /data/runs/iberia_test/GEOGRID.TBL GEOGRID.TBL

rm -f GRIBFILE.* FILE:* FILE.* met_em.d0* geo_em.d0*.nc geogrid.log ungrib.log metgrid.log \
      geogrid.stdout ungrib.stdout metgrid.stdout link_grib.out

echo "== geogrid =="
./geogrid.exe > geogrid.stdout 2>&1
grep -q "Successful completion" geogrid.log

echo "== ungrib (GFS 2025-06-29 00Z, f000-f072) =="
rm -f GRIBFILE.*
/opt/WPS/link_grib.csh "$METDIR"/gfs.* > link_grib.out 2>&1
./ungrib.exe > ungrib.stdout 2>&1
grep -q "Successful completion" ungrib.log

echo "== metgrid =="
./metgrid.exe > metgrid.stdout 2>&1
grep -q "Successful completion" metgrid.log

for dom in 01 02 03 04; do
  N=$(ls met_em.d${dom}.*.nc | wc -l)
  echo "WPS-OK d${dom}: $N ficheros met_em (esperados 49: 144 h a 3 h (3 d spin-up + episodio))"
  [ "$N" -eq 49 ]
done
