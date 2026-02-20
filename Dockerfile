# syntax=docker/dockerfile:1
ARG DOCKER_IMAGE=debian:trixie-slim
FROM $DOCKER_IMAGE AS builder

RUN apt-get update && apt-get install -y \
    build-essential cmake ninja-build git \
    libcurl4-gnutls-dev libzstd-dev libsqlite3-dev \
    libpq-dev libhiredis-dev libleveldb-dev libgmp-dev \
    libjsoncpp-dev libfreetype6-dev libopenal-dev \
    libvorbis-dev libogg-dev libglu1-mesa-dev libx11-dev \
    ca-certificates

RUN apt-get update && apt-get install -y \
    freeglut3-dev mesa-common-dev \
    libxxf86vm-dev libxext-dev

WORKDIR /usr/src/
RUN git clone --recursive https://github.com/jupp0r/prometheus-cpp && \
    cd prometheus-cpp && cmake -B build -DCMAKE_INSTALL_PREFIX=/usr -GNinja && \
    cmake --build build --target install

RUN git clone --recursive https://github.com/libspatialindex/libspatialindex && \
    cd libspatialindex && cmake -B build -DCMAKE_INSTALL_PREFIX=/usr && \
    cmake --build build --target install

RUN git clone --recursive https://luajit.org/git/luajit.git -b v2.1 luajit && \
    cd luajit && make amalg && make install PREFIX=/usr

WORKDIR /usr/src/luanti
COPY . .

RUN cmake -B build \
    -GNinja \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_BUILD_TYPE=Release \
    -DRUN_IN_PLACE=FALSE \
    -DBUILD_CLIENT=TRUE \
    -DBUILD_SERVER=TRUE \
    -DENABLE_FREETYPE=TRUE \
    -DENABLE_PROMETHEUS=TRUE \
    -DBUILD_UNITTESTS=FALSE

RUN cmake --build build

RUN cmake --install build --destdir /usr/src/pkg-root

RUN mkdir -p /usr/src/pkg-root/DEBIAN
RUN echo "Package: luanti-custom\n\
Version: 5.10.0\n\
Section: games\n\
Priority: optional\n\
Architecture: amd64\n\
Maintainer: Safwan Ehfaz Saad\n\
Depends: libjsoncpp25, libluajit-5.1-2, libfreetype6, libopenal1, libcurl4\n\
Description: Custom Luanti build including Shaders and Fonts." > /usr/src/pkg-root/DEBIAN/control

RUN dpkg-deb --build /usr/src/pkg-root /usr/src/luanti-custom.deb