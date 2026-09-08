#!/bin/bash
###############################################################################
# nuevo_caso.sh — crea un caso WRF nuevo a partir de la plantilla validada
#
# Uso:   bash scripts/nuevo_caso.sh NOMBRE YYYY-MM-DD_HH HORAS REF_LAT REF_LON
# Ejemplo: bash scripts/nuevo_caso.sh canarias 2026-09-10_00 48 28.2 -15.6
#
# Crea data/runs/NOMBRE con namelists (fechas/horas/centro ya ajustados),
# GEOGRID.TBL y scripts de ejecución. Después:
#   1. bash scripts/descargar_gfs.sh YYYYMMDD HH HORAS
#   2. ajusta METDIR en data/runs/NOMBRE/run_wps.sh (si difiere)
#   3. dominio/física extra: ver docs/GUIA-WRF-DOCKER.md §5-6
#   4. docker run ... wrf-wps:4.7.1  y dentro:
#      bash /data/runs/NOMBRE/run_wps.sh && bash /data/runs/NOMBRE/run_wrf.sh 14
###############################################################################
set -euo pipefail
NOMBRE=${1:?uso: nuevo_caso.sh NOMBRE YYYY-MM-DD_HH HORAS REF_LAT REF_LON}
INICIO=${2:?fecha inicio UTC YYYY-MM-DD_HH}
HORAS=${3:?horas de simulación}
RLAT=${4:?latitud central}
RLON=${5:?longitud central}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TPL="$ROOT/data/runs/iberia_test"
DEST="$ROOT/data/runs/$NOMBRE"

[ -e "$DEST" ] && { echo "ERROR: ya existe $DEST"; exit 1; }
FECHA_RE='^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}$'
echo "$INICIO" | grep -qE "$FECHA_RE" || { echo "ERROR: INICIO debe ser YYYY-MM-DD_HH (UTC)"; exit 1; }

Y=${INICIO:0:4}; M=${INICIO:5:2}; D=${INICIO:8:2}; H=${INICIO:11:2}
EPOCH_INI=$(date -u -d "${Y}-${M}-${D} ${H}:00:00" "+%s")
FIN=$(date -u -d "@$((EPOCH_INI + HORAS*3600))" "+%Y-%m-%d_%H")
FY=${FIN:0:4}; FM=${FIN:5:2}; FD=${FIN:8:2}; FH=${FIN:11:2}
echo "caso $NOMBRE: $INICIO + ${HORAS}h -> $FIN (UTC), centro $RLAT,$RLON"

mkdir -p "$DEST"
cp "$TPL/namelist.wps" "$TPL/namelist.input" "$TPL/GEOGRID.TBL" \
   "$TPL/run_wps.sh" "$TPL/run_wrf.sh" "$DEST/"

# --- namelist.wps: fechas y centro del dominio -------------------------------
sed -i "s|start_date = '[^']*'|start_date = '${INICIO}:00:00'|" "$DEST/namelist.wps"
sed -i "s|end_date   = '[^']*'|end_date   = '${FIN}:00:00'|" "$DEST/namelist.wps"
sed -i "s|ref_lat   = [0-9.]*|ref_lat   = ${RLAT}|"  "$DEST/namelist.wps"
sed -i "s|ref_lon   = -\?[0-9.]*|ref_lon   = ${RLON}|" "$DEST/namelist.wps"
sed -i "s|truelat1  = [0-9.]*|truelat1  = ${RLAT}|"  "$DEST/namelist.wps"
sed -i "s|truelat2  = [0-9.]*|truelat2  = ${RLAT}|"  "$DEST/namelist.wps"
sed -i "s|stand_lon = -\?[0-9.]*|stand_lon = ${RLON}|" "$DEST/namelist.wps"

# --- namelist.input: fechas, duración y centro -------------------------------
sed -i "s|run_hours                           = [0-9]*|run_hours                           = ${HORAS}|" "$DEST/namelist.input"
sed -i "s|start_year                          = [0-9]*|start_year                          = ${Y}|" "$DEST/namelist.input"
sed -i "s|start_month                         = [0-9]*|start_month                         = ${M}|" "$DEST/namelist.input"
sed -i "s|start_day                           = [0-9]*|start_day                           = ${D}|" "$DEST/namelist.input"
sed -i "s|start_hour                          = [0-9]*|start_hour                          = ${H}|" "$DEST/namelist.input"
sed -i "s|end_year                            = [0-9]*|end_year                            = ${FY}|" "$DEST/namelist.input"
sed -i "s|end_month                           = [0-9]*|end_month                           = ${FM}|" "$DEST/namelist.input"
sed -i "s|end_day                             = [0-9]*|end_day                             = ${FD}|" "$DEST/namelist.input"
sed -i "s|end_hour                            = [0-9]*|end_hour                            = ${FH}|" "$DEST/namelist.input"

# --- run_wps.sh: carpeta de GFS esperada (convención descargar_gfs.sh) -------
DIA_GFS="${Y}${M}${D}"
sed -i "s|METDIR=.*|METDIR=/data/meteo/gfs_${DIA_GFS}_${H}z|" "$DEST/run_wps.sh"

echo "--- creado $DEST ---"
grep -E "start_date|end_date|ref_lat|ref_lon" "$DEST/namelist.wps"
grep -E "run_hours|start_day|start_hour" "$DEST/namelist.input"
echo
echo "siguientes pasos:"
echo " 1) bash scripts/descargar_gfs.sh ${DIA_GFS} ${H} ${HORAS}"
echo " 2) dominio/física a medida: docs/GUIA-WRF-DOCKER.md §5-§6 (dx, e_we/e_sn, time_step≤6·dx_km)"
echo " 3) docker run --rm -it --network host --shm-size=2g -v $ROOT/data:/data wrf-wps:4.7.1"
echo "    y dentro: bash /data/runs/$NOMBRE/run_wps.sh && bash /data/runs/$NOMBRE/run_wrf.sh 14"
