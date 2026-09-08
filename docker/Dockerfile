# syntax=docker/dockerfile:1
###############################################################################
# WRF (Weather Research and Forecasting) — contenedor "solo WRF"
#
#   Base      : Ubuntu 22.04 limpio (nada del host)
#   Toolchain : gfortran/gcc 11.4 + OpenMPI 4.1.2 (apt)
#   netCDF    : netCDF-C 4.8.1 + netCDF-Fortran 4.5.4 (apt, congelados en la
#               capa de la imagen -> reproducible)
#   WRF       : tag de GitHub fijado por WRF_VERSION
#   Validación: tras compilar se ejecuta el caso idealizado em_b_wave y se
#               exige "SUCCESS COMPLETE WRF"; después se recompila em_real.
#
#   Build   : docker build -t wrf:4.7.1 --build-arg JOBS=8 -f docker/Dockerfile docker/
#   Uso     : ver README.md del proyecto
###############################################################################
FROM ubuntu:22.04

ARG WRF_VERSION=v4.7.1
ARG JOBS=8

ENV DEBIAN_FRONTEND=noninteractive

# ---- 1) Toolchain y librerías del sistema -----------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential gfortran m4 git curl ca-certificates csh tcsh python3 \
        libopenmpi-dev openmpi-bin \
        libnetcdf-dev libnetcdff-dev netcdf-bin \
        libhdf5-dev libxml2-dev libpng-dev libjpeg-dev zlib1g-dev \
        file procps less vim-tiny tzdata \
    && rm -rf /var/lib/apt/lists/*

ENV NETCDF=/usr

# ---- 2) Código fuente de WRF --------------------------------------------------
RUN git clone --depth 1 --branch ${WRF_VERSION} https://github.com/wrf-model/WRF.git /opt/WRF
WORKDIR /opt/WRF

# Física externa (physics_mmm, MYNN-EDMF, noahmp) vía submódulos gestionados
# por manage_externals (requiere python3)
RUN ./tools/manage_externals/checkout_externals --externals ./arch/Externals.cfg \
 && ls phys/physics_mmm/bl_gwdo.F90 >/dev/null

ENV FC=gfortran \
    CC=gcc

# configure: "34" = GNU gfortran/gcc (dmpar) | "1" = nesting básico
# (numeración verificada contra el menú de la v4.7.1 en Linux x86_64)
RUN printf '34\n1\n' | ./configure \
 && grep -q "dmpar" configure.wrf \
 && grep -q "mpif90" configure.wrf

# ---- 3) Compilación y smoke test (caso idealizado em_b_wave, 12 h) -----------
RUN ./compile -j ${JOBS} em_b_wave > /tmp/compile_bwave.log 2>&1 \
 && test -f main/wrf.exe \
 && test -f test/em_b_wave/ideal.exe \
 || { echo "=== TAIL compile_bwave.log ==="; tail -80 /tmp/compile_bwave.log; exit 1; }

RUN cd /opt/WRF/test/em_b_wave \
 && ./ideal.exe > ideal.out 2>&1 \
 && mpirun --allow-run-as-root \
           --mca btl_vader_single_copy_mechanism none \
           -np 4 ./wrf.exe > wrf.out 2>&1 \
 && grep -q "SUCCESS COMPLETE WRF" rsl.error.0000 \
 && rm -f wrfout* rsl.* ideal.out wrf.out

# ---- 4) Compilación final: em_real (casos con datos reales) -------------------
RUN ./compile -j ${JOBS} em_real > /tmp/compile_emreal.log 2>&1 \
 && test -f main/wrf.exe \
 && test -f main/real.exe

# ---- 5) Entorno de ejecución --------------------------------------------------
# OpenMPI en contenedor: permitir root y desactivar CMA de vader
ENV OMPI_ALLOW_RUN_AS_ROOT=1 \
    OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1 \
    OMPI_MCA_btl_vader_single_copy_mechanism=none \
    WRF_DIR=/opt/WRF

LABEL org.opencontainers.image.title="WRF (WRF-CHIMERE proyecto)" \
      org.opencontainers.image.version="4.7.1" \
      wrf.version="4.7.1" \
      wrf.build="gnu-dmpar" \
      wrf.core="em_real" \
      netcdf-c.version="4.8.1" \
      netcdf-fortran.version="4.5.4" \
      openmpi.version="4.1.2" \
      gfortran.version="11.4" \
      base.image="ubuntu:22.04"

WORKDIR /data
ENTRYPOINT ["/bin/bash"]
