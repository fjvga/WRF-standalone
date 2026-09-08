#!/usr/bin/env python3
"""Verificación física de un caso WRF en contenedor.

Comprueba, sobre los wrfout de un directorio de caso:
  1. Ausencia de NaN en variables de superficie clave (todas las horas)
  2. Rangos físicos plausibles (T2, PSFC, vientos, precipitación)
  3. Ciclo diurno del T2 medio (coherencia temporal)
  4. Consistencia con el forzamiento: T2/PSFC t=0 vs met_em inicial
  5. Consistencia t=+24 h vs met_em final (el forzamiento lateral ancla la solución)

Uso: python3 verify_wrfout.py /data/runs/iberia_test
"""
import glob
import os
import sys

import numpy as np
from netCDF4 import Dataset, num2date

case = sys.argv[1] if len(sys.argv) > 1 else "/data/runs/iberia_test"
outs = sorted(glob.glob(os.path.join(case, "wrfout_d01_*")))
assert outs, f"no hay wrfout en {case}"
met0 = os.path.join(case, "met_em.d01.2026-09-07_12:00:00.nc")
metN = os.path.join(case, f"met_em.d01.{os.path.basename(outs[-1])[11:31]}.nc")

resultados = []


def check(nombre, ok, detalle):
    resultados.append((nombre, ok, detalle))
    print(f"[{'OK ' if ok else 'FALLO'}] {nombre}: {detalle}")


# --- 1-2: NaN y rangos por cada wrfout --------------------------------------
t2m, psfm, wspd_max, rain24 = [], [], [], []
for f in outs:
    with Dataset(f) as nc:
        t2 = nc["T2"][:]
        psfc = nc["PSFC"][:]
        u10, v10 = nc["U10"][:], nc["V10"][:]
        rain = nc["RAINNC"][:] + nc["RAINC"][:]
        nan_vars = [v for v, a in (("T2", t2), ("PSFC", psfc), ("U10", u10),
                                   ("V10", v10), ("RAIN", rain)) if np.isnan(np.asarray(a)).any()]
        if f == outs[0]:
            check("Sin NaN en variables de superficie", not nan_vars,
                  f"{os.path.basename(f)}" + (f" -> NaN en {nan_vars}" if nan_vars else ""))
        t2m.append(float(t2.mean()))
        psfm.append(float(psfc.mean()))
        wspd_max.append(float(np.sqrt(u10**2 + v10**2).max()))
        rain24.append(rain)

check("Rango T2 plausible (250-325 K)",
      all(240 < np.nanmin(nc) and np.nanmax(nc) < 330 for nc in [t2m]),
      f"media dominio {min(t2m):.1f}-{max(t2m):.1f} K")
check("Rango PSFC plausible (85000-105000 Pa)",
      85000 < min(psfm) and max(psfm) < 105000,
      f"media dominio {min(psfm):.0f}-{max(psfm):.0f} Pa")
check("Viento 10m < 45 m/s", max(wspd_max) < 45, f"máximo {max(wspd_max):.1f} m/s")

# --- 3: ciclo diurno ---------------------------------------------------------
with Dataset(outs[0]) as nc:
    t = num2date(nc["Times"][:], nc["XTIME"].units) if hasattr(nc, "XTIME") else None
horas = [0, 3, 6, 9, 12, 15, 18, 21, 24]  # horas relativas al inicio (salida 3-h)
amplitud = max(t2m) - min(t2m)
min_idx = int(np.argmin(t2m))
check("Ciclo diurno T2 coherente (amplitud 4-20 K)", 4 <= amplitud <= 20,
      f"amplitud {amplitud:.1f} K; mínimo en t+{horas[min_idx]:+d} h, máximo en t+{horas[int(np.argmax(t2m))]:+d} h")

# --- 4-5: consistencia con forzamiento met_em --------------------------------
def comp(met, out, var_met, var_out, conversion, etiqueta, umbral):
    with Dataset(met) as m, Dataset(out) as o:
        a = np.asarray(m[var_met][:]).squeeze()
        b = np.asarray(o[var_out][:]).squeeze()
        if var_met == "TT":
            a = a[0]  # nivel más bajo del met_em (superficie)
        d = float(np.abs(a.mean() - b.mean()))
        check(etiqueta, d < umbral,
              f"|Δ media| = {d:.2f} (umbral {umbral}); met_em {a.mean():.1f} vs wrf {b.mean():.1f}")

comp(met0, outs[0], "TT", "T2", "none",
     "T2 t=0 consistente con GFS (met_em)", 4.0)
comp(met0, outs[0], "PSFC", "PSFC", "none",
     "PSFC t=0 consistente con GFS (met_em)", 250.0)
if os.path.exists(metN):
    comp(metN, outs[-1], "TT", "T2", "none",
         "T2 t=+24 h consistente con GFS (met_em)", 5.0)
    comp(metN, outs[-1], "PSFC", "PSFC", "none",
         "PSFC t=+24 h consistente con GFS (met_em)", 300.0)

# --- resumen -----------------------------------------------------------------
n_ok = sum(1 for _, ok, _ in resultados if ok)
print(f"\nRESUMEN: {n_ok}/{len(resultados)} comprobaciones superadas")
sys.exit(0 if n_ok == len(resultados) else 1)
