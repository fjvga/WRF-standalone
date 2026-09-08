#!/usr/bin/env python3
import csv
import math
import sys
from glob import glob
from pathlib import Path

import numpy as np
from netCDF4 import Dataset


def decode_time(t):
    if hasattr(t, 'tobytes'):
        return t.tobytes().decode('ascii').strip('\x00')
    return ''.join(x.decode('ascii') if isinstance(x, bytes) else str(x) for x in t).strip()


def haversine(lat1, lon1, lat2, lon2):
    r = 6371000.0
    p1 = np.radians(lat1)
    p2 = np.radians(lat2)
    dp = np.radians(lat2 - lat1)
    dl = np.radians(lon2 - lon1)
    a = np.sin(dp / 2.0) ** 2 + np.cos(p1) * np.cos(p2) * np.sin(dl / 2.0) ** 2
    return 2.0 * r * np.arcsin(np.sqrt(a))


def wind_dir_from(u, v):
    wd = (270.0 - np.degrees(np.arctan2(v, u))) % 360.0
    return wd


def main():
    domain = sys.argv[1] if len(sys.argv) > 1 else 'd04'
    plat = float(sys.argv[2]) if len(sys.argv) > 2 else 46.5128
    plon = float(sys.argv[3]) if len(sys.argv) > 3 else 6.6591
    radius_m = float(sys.argv[4]) if len(sys.argv) > 4 else 1000.0

    files = sorted(glob(f'wrfout_{domain}_*'))
    if not files:
        raise SystemExit(f'No se encontraron wrfout_{domain}_*')

    rows = []
    mask = None
    nearest_ij = None
    nearest_meta = None

    for path in files:
        with Dataset(path) as nc:
            if 'PBLH' not in nc.variables:
                raise SystemExit(f'PBLH no existe en {path}')

            lats = np.array(nc.variables['XLAT'][0, :, :])
            lons = np.array(nc.variables['XLONG'][0, :, :])
            dist = haversine(plat, plon, lats, lons)

            if mask is None:
                mask = dist <= radius_m
                if not np.any(mask):
                    iy, ix = np.unravel_index(np.argmin(dist), dist.shape)
                    mask[iy, ix] = True
                iy, ix = np.unravel_index(np.argmin(dist), dist.shape)
                nearest_ij = (int(iy), int(ix))
                nearest_meta = {
                    'grid_lat': float(lats[iy, ix]),
                    'grid_lon': float(lons[iy, ix]),
                    'distance_m': float(dist[iy, ix]),
                    'radius_m': float(radius_m),
                }

            pblh = np.array(nc.variables['PBLH'][:])
            u10 = np.array(nc.variables['U10'][:]) if 'U10' in nc.variables else np.full(pblh.shape, np.nan)
            v10 = np.array(nc.variables['V10'][:]) if 'V10' in nc.variables else np.full(pblh.shape, np.nan)
            times = nc.variables['Times'][:]

            iy, ix = nearest_ij
            for it in range(pblh.shape[0]):
                p = pblh[it, :, :]
                uu = u10[it, :, :]
                vv = v10[it, :, :]
                ws = np.sqrt(uu ** 2 + vv ** 2)
                rows.append({
                    'time_utc': decode_time(times[it]),
                    'domain': domain,
                    'target_lat': plat,
                    'target_lon': plon,
                    'radius_m': radius_m,
                    'grid_lat': nearest_meta['grid_lat'],
                    'grid_lon': nearest_meta['grid_lon'],
                    'distance_to_grid_m': nearest_meta['distance_m'],
                    'pblh_nearest_m': float(p[iy, ix]),
                    'pblh_mean_radius_m': float(np.nanmean(p[mask])),
                    'u10_ms': float(uu[iy, ix]),
                    'v10_ms': float(vv[iy, ix]),
                    'ws10_ms': float(ws[iy, ix]),
                    'wd_from_deg': float(wind_dir_from(uu[iy, ix], vv[iy, ix])),
                })

    outdir = Path('diagnostics')
    outdir.mkdir(exist_ok=True)
    csv_path = outdir / f'pully_pblh_{domain}.csv'
    txt_path = outdir / f'pully_pblh_{domain}_summary.txt'

    with csv_path.open('w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

    arr_nearest = np.array([r['pblh_nearest_m'] for r in rows], dtype=float)
    arr_mean = np.array([r['pblh_mean_radius_m'] for r in rows], dtype=float)
    wd = np.array([r['wd_from_deg'] for r in rows], dtype=float)
    ws = np.array([r['ws10_ms'] for r in rows], dtype=float)

    with txt_path.open('w') as f:
        f.write(f'domain={domain}\n')
        f.write(f'target_lat={plat}\n')
        f.write(f'target_lon={plon}\n')
        f.write(f'grid_lat={nearest_meta["grid_lat"]}\n')
        f.write(f'grid_lon={nearest_meta["grid_lon"]}\n')
        f.write(f'distance_to_grid_m={nearest_meta["distance_m"]:.1f}\n')
        f.write(f'radius_m={radius_m:.1f}\n')
        f.write(f'n_times={len(rows)}\n')
        f.write(f'pblh_nearest_min_m={np.nanmin(arr_nearest):.2f}\n')
        f.write(f'pblh_nearest_max_m={np.nanmax(arr_nearest):.2f}\n')
        f.write(f'pblh_nearest_mean_m={np.nanmean(arr_nearest):.2f}\n')
        f.write(f'pblh_radius_mean_min_m={np.nanmin(arr_mean):.2f}\n')
        f.write(f'pblh_radius_mean_max_m={np.nanmax(arr_mean):.2f}\n')
        f.write(f'pblh_radius_mean_mean_m={np.nanmean(arr_mean):.2f}\n')
        f.write(f'ws10_mean_ms={np.nanmean(ws):.2f}\n')
        f.write(f'wd_from_mean_deg={np.nanmean(wd):.2f}\n')

    print(csv_path)
    print(txt_path)


if __name__ == '__main__':
    main()
