# WRF-CHIMERE (fase 1-2: WRF + WPS en Docker, verificado y auditable)

Contenedores con **WRF v4.7.1 + WPS v4.7.0** compilados, validados con un caso
real (GFS → Iberia 12 km → 24 h) y con trazabilidad por simulación.

## 📘 Documentación

- **[docs/GUIA-WRF-DOCKER.md](docs/GUIA-WRF-DOCKER.md)** — guía completa para
  estudiantes: conceptos, primera simulación en 15 min, cómo descargar los
  datos de contorno GFS, cómo definir dominios (namelist param a param),
  física, ejecución, análisis, verificación, trazabilidad y problemas
  frecuentes.
- Helpers: `scripts/descargar_gfs.sh` (datos de contorno), `scripts/nuevo_caso.sh`
  (crear un caso nuevo en un comando), `scripts/verify_wrfout.py` (verificación
  física), `scripts/collect_provenance.sh` (expediente auditable).

## Imágenes

| Imagen | Contenido | Tamaño |
|---|---|---|
| `wrf:4.7.1` | Ubuntu 22.04 + WRF 4.7.1 (em_real, dmpar) | 2,5 GB |
| `wrf-wps:4.7.1` | extiende la anterior: WPS 4.7.0 + Jasper 2.0.33 + python3/netCDF4/numpy | +0,7 GB |

Versiones fijadas (también en labels OCI de la imagen): gfortran 11.4,
OpenMPI 4.1.2, netCDF-C 4.8.1, netCDF-Fortran 4.5.4, WRF/WPS/Jasper arriba.

```bash
# construir (desde la raíz del proyecto)
docker build -t wrf:4.7.1 -f docker/Dockerfile docker/
docker build -t wrf-wps:4.7.1 -f docker/Dockerfile.wps docker/
```

La imagen de WRF se **autovalida al construir** (caso idealizado em_b_wave,
exige `SUCCESS COMPLETE WRF`). La de WPS verifica los tres ejecutables.

## Datos (fuera de las imágenes, en `data/`)

- `data/geog/` — geog_complete (NCAR, 2017, 49 GB expandido). Nota: faltan las
  fuentes "modernas" (albedo_modis, GAIA urbano, irrigación); el caso usa
  `GEOGRID.TBL` local remapeado a las clásicas (ver `data/runs/iberia_test/`).
- `data/meteo/` — GFS 0.25° pgrb2 (AWS Open Data `noaa-gfs-bdp-pds`).

## Caso de verificación `data/runs/iberia_test`

Iberia 12 km (100×100, Lambert, 40 niveles), 24 h desde 2026-09-07 12Z,
física Thompson/RRTMG/YSU/Noah/KF, forzado con GFS.

```bash
# todo el pipeline (dentro del contenedor, con /data montado)
docker run --rm -it --network host --shm-size=2g \
  -v ~/Projects/WRF-CHIMERE/data:/data wrf-wps:4.7.1
bash /data/runs/iberia_test/run_wps.sh   # geogrid+ungrib+metgrid -> 9 met_em
bash /data/runs/iberia_test/run_wrf.sh 14 # real.exe + wrf.exe -> 9 wrfout
```

### Resultados de la verificación (2026-09-08)

1. **Reproducibilidad bit a bit**: dos ejecuciones de wrf.exe con idénticas
   entradas → 9/9 wrfout con el mismo sha256 (`provenance/`, `rerun1/`).
2. **Verificación física** (`scripts/verify_wrfout.py` → `verification.txt`):
   9/9 — sin NaN; T2 293-302 K; PSFC ~98 kPa; viento máx 13,6 m/s; ciclo
   diurno 8,6 K; **T2 t=0 = GFS (Δ=0,00 K)** y **t=+24 h Δ=0,61 K** respecto
   al forzamiento; PSFC coherente (Δ=25 Pa a +24 h).

### Trazabilidad / auditoría por simulación

Cada caso lleva `provenance/`:

- `manifest.txt` — imagen (ID sha256, labels de versiones), host, namelists
  íntegros con sus sha256, marcadores SUCCESS de cada etapa.
- `inputs.sha256` — checksums de los GFS usados + namelists.
- `outputs.sha256` — checksums de met_em, wrfinput, wrfbdy, wrfout y rsl.
- `geog_inventory.txt` — origen/URL e inventario del geodata.
- `verification.txt` — resultado de las comprobaciones físicas.

Generar con: `bash scripts/collect_provenance.sh data/runs/<caso> [imagen]`.

Trasladar imágenes: `docker save | gzip`, registro (ghcr.io), o
`apptainer build wrf.sif docker://...` en clústeres.

## Particularidades resueltas (por si se recompila)

- WRF 4.7+: `compile` es csh; la física externa (physics_mmm, MYNN, noahmp)
  llega por submódulos git → requiere `python3` y
  `./tools/manage_externals/checkout_externals --externals ./arch/Externals.cfg`.
- Ubuntu 22.04 retiró jasper → compilado desde fuente (tarball fijado en
  `docker/`, sha256 28d28290cc2e…) con `-DJAS_ENABLE_OPENGL=OFF`.
- WPS en Ubuntu solo enlaza `-lnetcdf` → parche `-lnetcdff` en configure.wps.
- Los wrfout de WRF 4.7 no llevan extensión `.nc`.
- `mpirun` dentro del contenedor necesita `--oversubscribe` (cuota de cgroup).

## Próxima fase: CHIMERE

El acoplamiento WRF–CHIMERE que plantea el proyecto usa el **WRF parcheado
que distribuyen los desarrolladores de CHIMERE** (no el WRF oficial). La
receta de `docker/Dockerfile` sirve tal cual cambiando la fuente del clone por
ese WRF parcheado; WPS/geog/GFS y todo el flujo de trazabilidad se reutilizan
sin cambios.
