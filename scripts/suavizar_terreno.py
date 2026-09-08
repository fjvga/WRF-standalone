#!/usr/bin/env python3
"""Suaviza la orografía de los nidos finos de un caso WRF (geogrid ya ejecutado).

Los dominios de alta resolución (≤1 km) sobre terreno alpino generan ruido
acústico vertical (w-CFL) que detona la integración en minutos. El suavizador
de geogrid (smth-desmth_special) es demasiado suave para acantilados de
~200 m/celda a 333 m. Este script aplica un filtro de Shapiro 1-4-6-4-1
(separable, ~5 celdas de escala) a HGT_M de los dominios indicados, con acote
de modificación máxima para no inventar relieve.

Uso (en el contenedor, sobre geo_em ya generados):
    python3 suavizar_terreno.py /data/runs/CASO d03 d04 [--pasadas 3] [--acote 80]

Después hay que re-ejecutar metgrid y real.exe (la interpolación meteorológica
depende del terreno).
"""
import argparse
import sys

import numpy as np
from netCDF4 import Dataset


def shapiro(campo, pasadas):
    k = np.array([1.0, 4.0, 6.0, 4.0, 1.0]) / 16.0
    out = campo.astype(float).copy()
    for _ in range(pasadas):
        tmp = np.apply_along_axis(lambda r: np.convolve(r, k, mode="same"), 1, out)
        out = np.apply_along_axis(lambda r: np.convolve(r, k, mode="same"), 0, tmp)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("caso", help="directorio del caso (p. ej. /data/runs/micaso)")
    ap.add_argument("dominios", nargs="+", help="dominios a suavizar: d03 d04 ...")
    ap.add_argument("--pasadas", type=int, default=3)
    ap.add_argument("--acote", type=float, default=80.0,
                    help="modificación máxima |ΔHGT| por celda (m)")
    a = ap.parse_args()

    for dom in a.dominios:
        ruta = f"{a.caso}/geo_em.{dom}.nc"
        with Dataset(ruta, "a") as nc:
            h = np.array(nc["HGT_M"][0])
            hs = np.clip(shapiro(h, a.pasadas), h - a.acote, h + a.acote)
            nc["HGT_M"][0] = hs
            g0 = np.abs(np.diff(h, axis=0)).max()
            g1 = np.abs(np.diff(hs, axis=0)).max()
            print(f"{dom}: gradiente max {g0:.0f} -> {g1:.0f} m/celda | "
                  f"|Δ| medio {np.abs(hs - h).mean():.1f} m, max {np.abs(hs - h).max():.0f} m")


if __name__ == "__main__":
    sys.exit(main())
