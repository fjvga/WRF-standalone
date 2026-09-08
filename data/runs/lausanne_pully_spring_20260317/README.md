# Caso primavera: Bise sobre Lausanne/Pully (2026-03-17 → 2026-03-20)

**Régimen estacional simulado**: vientos típicos de primavera — la Bise (NE).

## Justificación del episodio (selección con datos ERA5, punto 46.52N 6.66E)

Análisis horario de dirección/velocidad de viento a 10 m (ERA5, archivo
Open-Meteo) en Pully para marzo-abril 2026. Criterio de episodio de Bise:
dirección 20-70° sostenida ≥12 h con velocidad ≥3.5 m/s.

Episodios principales encontrados:

| Inicio | Duración | V máx | Dir media |
|---|---|---|---|
| **2026-03-16 19 UTC** | **63 h** | **28.7 m/s** | **33°** |
| 2026-03-27 02 UTC | 32 h | 29.6 m/s | 36° |
| 2026-03-31 06 UTC | 74 h | 27.3 m/s | 36° |

Se selecciona el del 16-19 de marzo: Bise fuerte y prolongada que cubre una
ventana de 72 h (ventana de interés 17→20 mar 00 UTC, spin-up desde 14 mar).

## Configuración

Idéntica a los casos winter/summer validados: 4 dominios (9/3/1/0.333 km),
MYNN, terreno d03/d04 suavizado (Shapiro), dt=27 s, w_damping, damp Rayleigh,
epssm=0.9, difusión terrain-aware, e_vert=44.

- Simulación: 2026-03-14_00 → 2026-03-20_00 UTC (144 h; 72 h de spin-up + episodio)
- Forzamiento: GFS 0.25° ciclo 2026-03-14 00Z (f000-f147, bucket AWS NOAA)
- Interés: canalización de la Bise en el eje del Léman, modulación por
  orografía y ciclos de brisa superpuestos.
