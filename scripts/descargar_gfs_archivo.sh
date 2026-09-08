#!/bin/bash
###############################################################################
# descargar_gfs_archivo.sh — descarga GFS 0.25° real-time o histórico
#
# Uso:   bash scripts/descargar_gfs_archivo.sh YYYYMMDD HH NHORAS
# Ej.:   bash scripts/descargar_gfs_archivo.sh 20250629 00 72
#
# Intenta primero AWS Open Data (ventana rolling) y, si no existe, cae a UCAR
# RDA histórico. Renombra todo al patrón esperado por WPS:
#   gfs.tHHz.pgrb2.0p25.fXXX
###############################################################################
set -euo pipefail
DIA=${1:?uso: descargar_gfs_archivo.sh YYYYMMDD HH NHORAS}
CICLO=${2:?ciclo 00|06|12|18}
HORAS=${3:?horas totales a cubrir}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DEST="$ROOT/data/meteo/gfs_${DIA}_${CICLO}z"
Y=${DIA:0:4}
AWS_BASE="https://noaa-gfs-bdp-pds.s3.amazonaws.com/gfs.${DIA}/${CICLO}/atmos"
RDA_BASE="https://data.rda.ucar.edu/d084001/${Y}/${DIA}"

mkdir -p "$DEST"
cd "$DEST"
FALLOS=0

for h in $(seq 0 3 "$HORAS"); do
  f=$(printf "%03d" "$h")
  target="gfs.t${CICLO}z.pgrb2.0p25.f${f}"
  tmp="${target}.part"

  if [ -s "$target" ] && [ "$(stat -c%s "$target")" -gt 10000000 ]; then
    echo "ya existe: $target"
    continue
  fi

  rm -f "$tmp"
  aws_url="${AWS_BASE}/${target}"
  rda_url="${RDA_BASE}/gfs.0p25.${DIA}${CICLO}.f${f}.grib2"

  echo "descargando $target ..."
  if curl -fSL --retry 3 --retry-delay 5 -o "$tmp" "$aws_url"; then
    mv "$tmp" "$target"
    continue
  fi

  echo "  AWS no disponible; intento archivo histórico UCAR RDA"
  if curl -fSL --retry 3 --retry-delay 5 -o "$tmp" "$rda_url"; then
    mv "$tmp" "$target"
    continue
  fi

  echo "  ERROR: no se pudo descargar $target desde AWS ni UCAR RDA"
  rm -f "$tmp"
  FALLOS=$((FALLOS+1))
done

echo "--- verificación de tamaños ---"
MALOS=0
for h in $(seq 0 3 "$HORAS"); do
  f=$(printf "%03d" "$h")
  target="gfs.t${CICLO}z.pgrb2.0p25.f${f}"
  if [ ! -s "$target" ] || [ "$(stat -c%s "$target" 2>/dev/null || echo 0)" -lt 10000000 ]; then
    echo "FALTA/INVÁLIDO: $target"
    MALOS=$((MALOS+1))
  fi
done

echo "resultado: $((HORAS/3+1-MALOS))/$((HORAS/3+1)) ficheros válidos en $DEST"
[ "$MALOS" -eq 0 ] && [ "$FALLOS" -eq 0 ] || {
  echo "descarga incompleta; repite el comando para reanudar"
  exit 1
}
