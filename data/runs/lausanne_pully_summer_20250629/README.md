# Lausanne/Pully verano 2025-06-29 → 2025-07-02

Caso WRF pensado para un episodio estival cálido con interés en crecimiento diurno de la PBL y brisa lacustre en Lausanne/Pully.

## Ventana
- Inicio: `2025-06-29 00 UTC`
- Final: `2025-07-02 00 UTC`
- Duración: `72 h`

## Motivación
El Bassin lémanique estuvo bajo aviso de canícula a finales de junio de 2025. Es una ventana útil para investigar altura de mezcla, forzamiento térmico del lago y modulación de la circulación local.

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
bash scripts/descargar_gfs_archivo.sh 20250629 00 72

docker run --rm -it --network host --shm-size=4g \
  -v $PWD/data:/data wrf-wps:4.7.1

bash /data/runs/lausanne_pully_summer_20250629/run_wps.sh
bash /data/runs/lausanne_pully_summer_20250629/run_wrf.sh 14
```

## Diagnóstico PBLH
Al terminar `run_wrf.sh`, se generan automáticamente en `diagnostics/` series temporales de PBLH sobre Pully para d03 y d04.
