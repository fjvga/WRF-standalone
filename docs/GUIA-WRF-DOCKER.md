# Guía práctica: WRF en Docker — de cero a tu primera simulación

Guía para estudiantes de posgrado. Al finishing habrás corrido una simulación
WRF de 24 h sobre la península ibérica forzada con GFS, y sabrás cambiar
dominio, fechas, resolución y física. No necesitas instalar nada de WRF: todo
va en contenedores Docker.

> Convención: los bloques que empiezan con `$` se ejecutan en tu terminal del
> host; los que empiezan con `#` dentro del contenedor. Rutas `/data/...`
> son el directorio `data/` del proyecto visto desde dentro del contenedor.

---

## 1. Conceptos en diez líneas

- **WRF** es un modelo meteorológico mesoescalar: resuelve la atmósfera en una
  malla 3D regional que TÚ defines, y la integra en el tiempo.
- **GFS** es el modelo global de NOAA (~28 km, 4 ciclos/día, gratis). Le
  pedimos prestadas las condiciones iniciales (CI) y de contorno (LBC:
  *lateral boundary conditions*, lo que "entra" por los bordes de tu dominio).
- **WPS** (preprocesado) prepara todo en tres pasos:
  - **geogrid**: crea tu malla y la rellena con datos fijos (orografía,
    usos del suelo,…) desde `data/geog`.
  - **ungrib**: decodifica los GRIB2 de GFS al formato intermedio WPS.
  - **metgrid**: interpola GFS (horizontal y verticalmente) a tu malla →
    ficheros `met_em.d01.<fecha>`, uno por tiempo de contorno.
- **WRF** (modelo) en dos pasos:
  - **real.exe**: crea la CI (`wrfinput_d01`) y la LBC (`wrfbdy_d01`) a partir
    de los `met_em`.
  - **wrf.exe**: integra el modelo → salidas `wrfout_d01_<fecha>` (netCDF).
- La cadena completa: **GFS → geogrid → ungrib → metgrid → real → wrf**.

```
GFS (grb2) ──ungrib──► FILE:fecha ─┐
                                   ├─metgrid─► met_em.d01.fecha ─┐
geog ──geogrid──► geo_em.d01.nc ───┘                            ├─real─► wrfinput_d01 + wrfbdy_d01
                                                                └──────────────► wrf.exe ──► wrfout_d01_*
```

## 2. Requisitos

1. Linux con **Docker** y tu usuario en el grupo `docker`
   (`sudo usermod -aG docker $USER` y reinicia sesión).
2. Este repositorio: `git clone <repo>` → `cd WRF-CHIMERE`.
3. Las dos imágenes (ya construidas en el servidor; si no, ver §12):
   `wrf:4.7.1` (WRF) y `wrf-wps:4.7.1` (WRF+WPS+análisis).
4. Disco: `data/geog` 49 GB ya en el servidor; cada caso consume
   ~6 GB de GFS + ~1-2 GB de salidas por 24 h.

Comprueba que todo responde:

```bash
$ docker images wrf-wps           # debe listar wrf-wps:4.7.1
$ ls data/geog | head -3          # albedo_ncep, clayfrac_5m, erod...
```

## 3. Tu primera simulación (el caso `iberia_test`, 15 minutos)

Entra en el contenedor montando `data/`:

```bash
$ cd ~/Projects/WRF-CHIMERE
$ docker run --rm -it --network host --shm-size=2g \
    -v ~/Projects/WRF-CHIMERE/data:/data wrf-wps:4.7.1
```

Dentro, lanza el preprocesado y después el modelo:

```bash
# bash /data/runs/iberia_test/run_wps.sh      # ~5 min
# bash /data/runs/iberia_test/run_wrf.sh 14   # ~10 min (14 núcleos)
```

Cada script comprueba por sí mismo el éxito (busca `Successful completion`
o `SUCCESS COMPLETE`); si acaban sin errores, tienes 9 salidas:

```bash
# ls /data/runs/iberia_test/wrfout_d01_2*     # 9 ficheros (3-h) sin extensión .nc
# exit
```

Inspección rápida de una salida (dentro o fuera del contenedor):

```bash
$ docker run --rm -v $PWD/data:/data wrf-wps:4.7.1 \
    -c 'ncdump -h /data/runs/iberia_test/wrfout_d01_2026-09-07_12:00:00 | head -40'
```

## 4. Los datos de contorno: descargar GFS

Para simular **otras fechas** necesitas tu propio GFS. Se distribuye gratis
en el bucket público de AWS (NOAA). Un fichero = un tiempo; para una
simulación de N horas con contornos cada 3 h necesitas N/3+1 ficheros.

**URL** (fíjate en el patrón; YYYYMMDD = día, HH = ciclo 00/06/12/18 UTC,
fXXX = hora de pronóstico):

```
https://noaa-gfs-bdp-pds.s3.amazonaws.com/gfs.YYYYMMDD/HH/atmos/gfs.tHHz.pgrb2.0p25.fXXX
   ejemplo: .../gfs.20260907/12/atmos/gfs.t12z.pgrb2.0p25.f000
```

Reglas prácticas:
- Cada ciclo está disponible ~4-5 h después de su hora nominal (el 12Z,
  hacia las 16-17Z). La NASA/NOAA conserva ~10 días en ese bucket; para
  fechas más viejas usar el archive (research or NCEI).
- Elige el ciclo más cercano ANTERIOR a tu hora de inicio y descarga
  desde f000 hasta cubrir tu simulación + 3 h de margen.
- ~330 MB por fichero (0.25°, todos los niveles). Una simulación de 24 h
  son 9-13 ficheros ≈ 3-4 GB.

Descarga con el helper del repo (en el host):

```bash
$ bash scripts/descargar_gfs.sh 20260907 12 24   # día, ciclo UTC, horas totales
   # → data/meteo/gfs_20260907_12z/gfs.t12z.pgrb2.0p25.f000 ... f024
```

Verifica siempre: número de ficheros correcto y tamaños ~3×10⁸ bytes
(un fichero de 20 KB es un error de descarga, bórralo y repite).

## 5. Definir tu dominio (namelist.wps, param a param)

El dominio es la caja donde WRF vive. Se define en `namelist.wps`, grupo
`&geogrid` (y las fechas en `&share`). Plantilla: copia la del caso
`iberia_test` o usa `scripts/nuevo_caso.sh` (§7).

| Parámetro | Qué es | Cómo elegirlo |
|---|---|---|
| `ref_lat`, `ref_lon` | Centro del dominio | Lat/lon del fenómeno (p. ej. ciudad o región) |
| `dx`, `dy` | Tamaño de celda (m) | 12 km = sinyopsis regional; 3 km = convección (sin cúmulos parametrizados); 1 km = investigación |
| `e_we`, `e_sn` | nº de celdas E-O y N-S | Impares recomendado. Extensión = (e_we−1)×dx. 100×12 km ≈ 1200 km |
| `map_proj` | Proyección | `lambert` para latitudes medias; `mercator` trópicos; `polar` altas |
| `truelat1`, `truelat2` | Paralelos de Lambert | truelat1 ≈ latitud media del dominio; truelat2 = truelat1 (dominios pequeños) |
| `stand_lon` | Meridiano de referencia | ≈ longitud central |
| `geog_data_res` | Resolución de datos fijos | `default` (elige solo: 30 s a 10 min según dx) |
| `geog_data_path` | Ruta al geodata | `/data/geog` (no tocar) |

En `&share` (¡fechas en UTC!):

| Parámetro | Qué es |
|---|---|
| `start_date` / `end_date` | Ventana con contornos: desde tu hora inicial hasta final de simulación |
| `interval_seconds` | Separación entre contornos: **10800** (GFS 3-h). Debe coincidir con `interval_seconds` del namelist.input |
| `wrf_core` | `ARW` (no tocar) |

**Dominios anidados** (d02 dentro de d01, 3:1): añade en `&geogrid` los
arrays (`parent_id=1,1`, `parent_grid_ratio=1,3`, `i_parent_start=1,31`,
`e_we=100,112`, `geog_data_res='default','default'`,…) y replica fechas con
comas. Reglas: ratio entero (3 típico), el paso de tiempo se divide por el
ratio, y d02 debe quedar al menos a 5 celdas del borde de d01. **Consejo:
domina primero el dominio único.**

## 6. La física y el paso de tiempo (namelist.input)

Los grupos críticos (plantilla del caso ya validada):

`&time_control` — `run_hours` (duración), `start_*`/`end_*` (deben casar con
los met_em disponibles), `history_interval=180` (salida cada 3 h),
`frames_per_outfile=1`, `io_form_*=2` (netCDF clásico).

`&domains`:

| Parámetro | Valor del caso | Nota |
|---|---|---|
| `time_step` | 72 | **Regla: ≤ 6×dx_km** (12 km→72 s; 3 km→18 s). Si el modelo "explota", bájalo |
| `e_vert` | 40 | Niveles verticales (30-57 usual) |
| `p_top_requested` | 5000 | Techo del modelo en Pa (no tocar) |
| `num_metgrid_levels` | 34 | Lo pone GFS 0.25° (verifícalo: `ncdump -h met_em... | grep num_metgrid`) |
| `num_metgrid_soil_levels` | 4 | GFS (no tocar) |

`&physics` — la combinación del caso es estándar y robusta para 12 km:

| Opción | Valor | Esquema |
|---|---|---|
| `mp_physics` | 8 | Microfísica Thompson |
| `cu_physics` | 1 | Cúmulos Kain-Fritsch (**0** si dx ≤ 5 km) |
| `ra_lw/sw_physics` | 4/4 | Radiación RRTMG |
| `bl_pbl_physics` | 1 | PBL YSU |
| `sf_sfclay_physics` | 1 | Capa superficie (pareada con YSU) |
| `sf_surface_physics` | 2 | Suelo Noah |
| `radt` | 12 | ≈ dx en km |
| `num_land_cat` | 21 | MODIS (lo que produce este geodata) |

`&bdy_control` — `specified=.true.` y `spec_bdy_width=5` (dominio único con
contornos; no tocar).

## 7. Crear un caso nuevo

```bash
$ bash scripts/nuevo_caso.sh micaso 2026-09-10_00 48 36.7 -6.0
   # nombre, inicio (UTC), horas de simulación, lat y lon del centro
   # → crea data/runs/micaso con namelists y scripts ya configurados
```

Revisa/edita si quieres: dominio (§5), física (§6). Descarga el GFS de esas
fechas (§4) y ajusta `METDIR` en `run_wps.sh` a tu carpeta. Después: §3
(con las rutas de tu caso).

## 8. Ejecutar y monitorizar

Dentro del contenedor, en tu directorio de caso:

```bash
# bash /data/runs/micaso/run_wps.sh          # geogrid+ungrib+metgrid
# bash /data/runs/micaso/run_wrf.sh 14       # real+wrf (nº núcleos ≤ 16)
```

- El progreso real está en `rsl.error.0000`: líneas `Timing for main`
  (una por paso); el tiempo simulado avanza `time_step` s por línea.
- Criterio de éxito: `d01 <fecha final> wrf: SUCCESS COMPLETE WRF` al final
  de `rsl.error.0000`.
- Si wrf.exe muere sin mensaje claro: mira las últimas `d01 ... FATAL` de
  `rsl.error.0000` y el §11.

## 9. Salidas y análisis básico

- `wrfout_d01_YYYY-MM-DD_HH:MM:SS` — estado completo 3D por tiempo de
  salida. Variables útiles: `T2` (temp. 2 m, K), `PSFC` (presión superficie,
  Pa), `U10/V10` (viento 10 m), `RAINNC+RAINC` (precip. acumulada, mm),
  `Q2`, `HGT` (orografía), `T` (temp. potencial perturbada 3D), `U/V/P/HB`
  … (3D en niveles sigma `bottom_top`).
- Inspección: `ncdump -h fichero` (cabecera), `ncview` (en tu host),
  python `wrf-python`/`netCDF4`. Ejemplo de lectura con la imagen:
  ```bash
  $ docker run --rm -v $PWD/data:/data wrf-wps:4.7.1 -c \
    'python3 -c "from netCDF4 import Dataset; import numpy as np; \
     nc=Dataset(\"/data/runs/iberia_test/wrfout_d01_2026-09-07_12:00:00\"); \
     print(\"T2 media (C):\", (nc[\"T2\"][:].mean()-273.15).round(1))"'
  ```

## 10. Verificación y trazabilidad (auditoría del resultado)

1. **Verificación física** (NaN, rangos, coherencia con el GFS forzante):
   ```bash
   $ docker run --rm --network host -v $PWD/data:/data -v $PWD/scripts:/scripts \
       wrf-wps:4.7.1 -c 'python3 /scripts/verify_wrfout.py /data/runs/micaso' \
       | tee data/runs/micaso/verification.txt
   ```
2. **Reproducibilidad**: borra `wrfout_d01_*`, repite wrf.exe y compara
   `sha256sum`. Con los mismos inputs y nº de procesos, deben ser idénticos.
3. **Expediente de procedencia** (imagen exacta + checksums de todo):
   ```bash
   $ bash scripts/collect_provenance.sh data/runs/micaso wrf-wps:4.7.1
   ```
   Genera `provenance/{manifest.txt,inputs.sha256,outputs.sha256,
   geog_inventory.txt}`. **Guárdalos junto al caso**: son la prueba de con
   qué se hizo y permiten reconstruirlo/auditarlo.

## 11. Problemas frecuentes

| Síntoma (en rsl/log) | Causa | Solución |
|---|---|---|
| `error opening met_em.d01... bad date` | Fechas del namelist no coinciden con los met_em | Revisa `start/end_*` y que GFS cubre el periodo |
| `Mismatch ... NUM_LAND_CAT` | namelist vs geodata | Con este geodata: `num_land_cat=21` |
| `num_metgrid_levels` mismatch | Fuente distinta de GFS 0.25 | `ncdump -h met_em | grep num_metgrid` y ajusta |
| geogrid: `Could not open /data/geog/...` | TBL pide fuente ausente | Usa el `GEOGRID.TBL` del caso iberia_test |
| mpirun: `not enough slots` | Cuota de CPUs del contenedor | `mpirun --oversubscribe -np N` (ya en los scripts) |
| wrf se para con `SIGSEGV`/CFL | dt demasiado grande o inestabilidad | Baja `time_step` a la mitad |
| `wrfout_d01_*.nc` no existe | WRF 4.7 no pone `.nc` | Usa el patrón `wrfout_d01_2*` |
| ungrib: `no GRIB FILE` | link_grib no vio ficheros | Ruta correcta en `run_wps.sh` (METDIR) |
| real.exe ok pero 0 met_em usados | namelist.wps end_date < start_date | Fechas en UTC y orden correcto |

## 12. Llevarlo a otra máquina

- **Otra estación con Docker**: `docker save wrf-wps:4.7.1 | gzip > img.tgz`
  → copiar → `docker load < img.tz` (más `data/geog` una sola vez, y los
  GFS del caso). O publicar en un registro y `docker pull`.
- **Clúster HPC** (sin Docker): convertir con Apptainer
  `apptainer build wrf.sif docker-daemon://wrf-wps:4.7.1` y ejecutar
  `mpirun -np 64 wrf.sif /opt/WRF/main/wrf.exe`.

## 13. Glosario mínimo

CI/LBC — condiciones iniciales / de contorno. met_em — GFS interpolado a tu
malla. wrfinput — estado inicial del modelo. wrfbdy — contornos laterales.
CFL — condición de estabilidad que limita `time_step`. d01/d02 — dominio
madre/anidado. ciclo GFS — una de las 4 ejecuciones diarias (00/06/12/18 UTC).
