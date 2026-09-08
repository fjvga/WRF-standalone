#!/bin/bash
###############################################################################
# collect_provenance.sh — expediente de trazabilidad/auditoría de una simulación
#
# Genera en  RUN_DIR/provenance/ :
#   manifest.txt      : imagen (ID, labels, fecha), host, namelists, éxito
#   inputs.sha256     : checksums de datos de entrada (GFS, namelists, geog)
#   outputs.sha256    : checksums de salidas (wrfout*, wrfinput, wrfbdy, logs)
#
# Uso: ./collect_provenance.sh RUN_DIR [IMAGEN]
#      (IMAGEN por defecto: wrf-wps:4.7.1; se ejecuta en el HOST con docker)
###############################################################################
set -euo pipefail
RUN_DIR=${1:?uso: collect_provenance.sh RUN_DIR [IMAGEN]}
IMAGE=${2:-wrf-wps:4.7.1}
PROJ=/home/francisco/Projects/WRF-CHIMERE
PROV="$RUN_DIR/provenance"
mkdir -p "$PROV"

run() { sg docker -c "$1"; }

{
  echo "==============================================================="
  echo " MANIFIESTO DE PROCEDENCIA — simulación WRF en contenedor"
  echo "==============================================================="
  echo "generado_utc      : $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "host              : $(uname -srm) | $(hostname)"
  echo "run_dir           : $RUN_DIR"
  echo
  echo "--- Imagen del contenedor -------------------------------------"
  run "docker inspect --format 'imagen_id        : {{.Id}}' $IMAGE"
  run "docker inspect --format 'imagen_creada    : {{.Created}}' $IMAGE"
  run "docker inspect --format 'imagen_repo_tags : {{.RepoTags}}' $IMAGE"
  echo "labels            :"
  run "docker inspect --format '{{range \$k, \$v := .Config.Labels}}  {{\$k}}={{\$v}}
{{end}}' $IMAGE" | sed '/^$/d'
  echo
  echo "--- Versiones internas (ejecutadas en la imagen) ---------------"
  run "docker run --rm $IMAGE -c 'nc-config --version | sed s/^/  /; mpif90 --version | head -1 | sed s/^/  /; ls /opt/WRF/main/wrf.exe /opt/WPS/geogrid/src/geogrid.exe 2>/dev/null | sed s/^/  existe: /'" 2>/dev/null || echo "  (imagen no disponible)"
  echo
  echo "--- Configuración del caso -------------------------------------"
  for f in namelist.wps namelist.input; do
    [ -f "$RUN_DIR/$f" ] && { echo ">> $f (sha256: $(sha256sum "$RUN_DIR/$f" | cut -d' ' -f1))"; sed 's/^/  | /' "$RUN_DIR/$f"; echo; }
  done
  echo "--- Resultado --------------------------------------------------"
  for f in rsl.error.0000 rsl.out.0000 geogrid.log ungrib.log metgrid.log; do
    [ -f "$RUN_DIR/$f" ] && grep -H "SUCCESS" "$RUN_DIR/$f" | sed 's/^/  /' || true
  done
  echo "wrfout_generados  : $(ls "$RUN_DIR"/wrfout_d01_* 2>/dev/null | wc -l)"
} > "$PROV/manifest.txt"

# Checksums de entradas (datos GFS + namelists; geog como inventario)
{
  echo "# Entradas de la simulación — sha256 — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  find "$PROJ/data/meteo" -type f -name 'gfs.*' -print0 | sort -z | xargs -0 sha256sum
  sha256sum "$RUN_DIR/namelist.wps" "$RUN_DIR/namelist.input"
} > "$PROV/inputs.sha256"

# Inventario de geog (hash completo de 30 GB sería costoso: inventario de contenido)
{
  echo "# Inventario geog (fuente: geog_complete.tar.gz, Last-Modified 2017-11-01, NCAR)"
  echo "# URL: https://www2.mmm.ucar.edu/wrf/src/wps_files/geog_complete.tar.gz"
  du -sh "$PROJ/data/geog"
  find "$PROJ/data/geog" -maxdepth 1 -mindepth 1 -printf '%f\n' | sort
} > "$PROV/geog_inventory.txt"

# Checksums de salidas e inputs intermedios
{
  echo "# Salidas e intermedios — sha256 — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  cd "$RUN_DIR"
  sha256sum met_em*.nc wrfinput_d01 wrfbdy_d01 wrfout_d01_*.nc rsl.error.0000 2>/dev/null || true
} > "$PROV/outputs.sha256"

echo "PROVENANCE-OK: $PROV"
ls -la "$PROV"
