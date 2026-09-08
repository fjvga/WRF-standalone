# Configuración WRF para Lausanne/Pully

Este branch añade dos casos listos para ejecutar sobre Lausanne/Pully con foco en altura de capa límite (PBLH) en la zona de Pully y resolución anidada hasta 333 m:

- `data/runs/lausanne_pully_winter_20260115/` — episodio invernal estable/inversión.
- `data/runs/lausanne_pully_summer_20250629/` — episodio estival cálido con potencial de brisa lacustre.
- `scripts/descargar_gfs_archivo.sh` — descarga GFS 0.25° desde AWS y, si hace falta, cae al archivo histórico UCAR RDA.

## Justificación de episodios

### Invierno: 2026-01-15 00 UTC → 2026-01-18 00 UTC
MétéoSuisse informó que tras el episodio de nieve del 8–11 de enero de 2026 se instalaron condiciones anticiclónicas y secas favorables a inversiones térmicas y nieblas durante alrededor de diez días en Suiza romanda y Valais. El boletín estacional también destaca stratus/inversión en la segunda mitad de enero de 2026 sobre el Plateau.

### Verano: 2025-06-29 00 UTC → 2025-07-02 00 UTC
Durante el episodio cálido de finales de junio e inicios de julio de 2025 hubo aviso de canícula de grado 3 para el Bassin lémanique, y la primera semana de julio de 2025 fue muy cálida. Es una ventana útil para diagnosticar crecimiento diurno de la PBL y la modulación lacustre.

## Resoluciones

Los dos casos usan 4 dominios anidados:

- d01 = 9 km
- d02 = 3 km
- d03 = 1 km
- d04 = 333 m

Con esta configuración se mantiene razón 3:1 entre dominios, un `time_step` entero y un dominio interno suficientemente fino para PBLH en Pully sin entrar de lleno en una configuración LES de 100–150 m, que requeriría más validación y retocado físico.

## Física elegida

- `mp_physics = 8` Thompson
- `ra_lw/sw_physics = 4/4` RRTMG
- `bl_pbl_physics = 5` MYNN
- `sf_sfclay_physics = 5` MYNN surface layer
- `sf_surface_physics = 2` Noah LSM
- `cu_physics = 1,0,0,0` solo en d01

El objetivo es priorizar una PBL más útil para estabilidad/inversión y evitar cúmulos parametrizados en las mallas convective-permitting.

## Vientos especiales del Léman

Estos casos están pensados para poder reusar la misma malla cuando quieras retargetear episodios con:

- **Bise** (NE), muy relevante en Lausanne/Pully.
- **Vent** (SW).
- **Joran** (NW, más brusco y raro).
- **Vaudaire** (SE, más propia del Haut-Lac pero puede modular la circulación del Grand-Lac).
- **Brisas lacustres** diurnas/nocturnas en verano.

Para cambiar fechas conservando toda la geometría, basta editar las fechas y `METDIR` o duplicar el caso.

## Ejecución rápida

### Invierno
```bash
bash scripts/descargar_gfs_archivo.sh 20260115 00 72

docker run --rm -it --network host --shm-size=4g \
  -v $PWD/data:/data wrf-wps:4.7.1

bash /data/runs/lausanne_pully_winter_20260115/run_wps.sh
bash /data/runs/lausanne_pully_winter_20260115/run_wrf.sh 14
```

### Verano
```bash
bash scripts/descargar_gfs_archivo.sh 20250629 00 72

docker run --rm -it --network host --shm-size=4g \
  -v $PWD/data:/data wrf-wps:4.7.1

bash /data/runs/lausanne_pully_summer_20250629/run_wps.sh
bash /data/runs/lausanne_pully_summer_20250629/run_wrf.sh 14
```

## Salidas PBLH

Cada `run_wrf.sh` lanza al final `extract_pblh_pully.py`, que genera en `diagnostics/`:

- `pully_pblh_d03.csv`
- `pully_pblh_d04.csv`
- `pully_pblh_d03_summary.txt`
- `pully_pblh_d04_summary.txt`

Los CSV incluyen para cada tiempo:

- `pblh_nearest_m`
- `pblh_mean_radius_m`
- `u10_ms`, `v10_ms`, `ws10_ms`, `wd_from_deg`
- coordenadas del punto de celda más cercano a Pully

## Notas

- El helper histórico intenta AWS primero; para fechas antiguas usa UCAR RDA.
- Si quieres empujar el dominio interno a ~111 m, mejor hacerlo en una rama aparte con validación específica gray-zone/LES.
