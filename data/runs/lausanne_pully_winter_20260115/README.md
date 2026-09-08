# Lausanne/Pully invierno 2026-01-15 → 2026-01-18

Caso WRF pensado para un episodio de estabilidad/inversión sobre Lausanne y Pully.

## Ventana
- Inicio: `2026-01-15 00 UTC`
- Final: `2026-01-18 00 UTC`
- Duración: `72 h`

## Motivación
La segunda mitad de enero de 2026 tuvo condiciones favorables a inversión térmica y nieblas persistentes en Suiza romanda, útiles para estudiar una PBL baja y estable.

## Resolución
- d01 = 9 km
- d02 = 3 km
- d03 = 1 km
- d04 = 333 m

## Centro del dominio
- `ref_lat = 46.515`
- `ref_lon = 6.655`

## Ejecución
```bash
bash scripts/descargar_gfs_archivo.sh 20260115 00 72

docker run --rm -it --network host --shm-size=4g \
  -v $PWD/data:/data wrf-wps:4.7.1

bash /data/runs/lausanne_pully_winter_20260115/run_wps.sh
bash /data/runs/lausanne_pully_winter_20260115/run_wrf.sh 14
```

## Diagnóstico PBLH
Al terminar `run_wrf.sh`, se generan automáticamente en `diagnostics/` series temporales de PBLH sobre Pully para d03 y d04.
