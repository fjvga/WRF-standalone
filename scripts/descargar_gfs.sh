#!/bin/bash
###############################################################################
# descargar_gfs.sh — descarga GFS 0.25° (pgrb2) del bucket público de NOAA/AWS
#
# Uso:   bash scripts/descargar_gfs.sh YYYYMMDD HH NHORAS
#        YYYYMMDD  día del ciclo   HH  ciclo (00|06|12|18 UTC)
#        NHORAS    horas de pronóstico a cubrir (contornos cada 3 h)
# Ejemplo: bash scripts/descargar_gfs.sh 20260907 12 24
#
# Destino: data/meteo/gfs_YYYYMMDD_HHz/gfs.tHHz.pgrb2.0p25.fXXX
# Nota: el ciclo está disponible ~4-5 h después de su hora nominal.
###############################################################################
set -euo pipefail
DIA=${1:?uso: descargar_gfs.sh YYYYMMDD HH NHORAS}
CICLO=${2:?ciclo 00|06|12|18}
HORAS=${3:?horas totales a cubrir}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DEST="$ROOT/data/meteo/gfs_${DIA}_${CICLO}z"
BASE="https://noaa-gfs-bdp-pds.s3.amazonaws.com/gfs.${DIA}/${CICLO}/atmos"

mkdir -p "$DEST"
cd "$DEST"
FALLOS=0
for h in $(seq 0 3 "$HORAS"); do
  f=$(printf "f%03d" "$h")
  fichero="gfs.t${CICLO}z.pgrb2.0p25.${f}"
  if [ -s "$fichero" ] && [ "$(stat -c%s "$fichero")" -gt 10000000 ]; then
    echo "ya existe: $fichero"; continue
  fi
  echo "descargando $fichero ..."
  curl -fSL --retry 3 --retry-delay 5 -o "$fichero" "${BASE}/${fichero}" || FALLOS=$((FALLOS+1))
done

echo "--- verificación de tamaños (un fichero válido ~3x10^8 bytes) ---"
MALOS=0
for h in $(seq 0 3 "$HORAS"); do
  f=$(printf "f%03d" "$h")
  fichero="gfs.t${CICLO}z.pgrb2.0p25.${f}"
  if [ ! -s "$fichero" ] || [ "$(stat -c%s "$fichero" 2>/dev/null || echo 0)" -lt 10000000 ]; then
    echo "FALTA/INVÁLIDO: $fichero"; MALOS=$((MALOS+1))
  fi
done
echo "resultado: $((HORAS/3+1-MALOS))/$((HORAS/3+1)) ficheros válidos en $DEST"
[ "$MALOS" -eq 0 ] && [ "$FALLOS" -eq 0 ] || { echo "repítelo: reanuda donde falló"; exit 1; }
