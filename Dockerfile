# syntax=docker/dockerfile:1
ARG DOCKER_IMAGE=debian:trixie-slim
FROM $DOCKER_IMAGE AS dev

ENV LUAJIT_VERSION=v2.1

RUN apt-get update && apt-get install -y \
    build-essential cmake ninja-build git \
    libcurl4-gnutls-dev libzstd-dev libsqlite3-dev \
    libpq-dev libhiredis-dev libleveldb-dev libgmp-dev \
    libjsoncpp-dev libfreetype6-dev libopenal-dev \
    libvorbis-dev libogg-dev libglu1-mesa-dev libx11-dev \
    libxxf86vm-dev libxext-dev freeglut3-dev mesa-common-dev \
    ca-certificates libjpeg-dev libsdl2-dev

RUN git clone --recursive https://github.com/jupp0r/prometheus-cpp && \
    cd prometheus-cpp && cmake -B build -DCMAKE_INSTALL_PREFIX=/usr -GNinja && \
    cmake --build build --target install

RUN git clone --recursive https://github.com/libspatialindex/libspatialindex && \
    cd libspatialindex && cmake -B build -DCMAKE_INSTALL_PREFIX=/usr && \
    cmake --build build --target install

RUN git clone --recursive https://luajit.org/git/luajit.git -b ${LUAJIT_VERSION} && \
    cd luajit && make amalg && make install PREFIX=/usr

FROM dev AS builder

WORKDIR /usr/src/luanti

COPY . .
COPY .git /usr/src/luanti/.git
COPY CMakeLists.txt /usr/src/luanti/CMakeLists.txt
COPY README.md /usr/src/luanti/README.md
COPY minetest.conf.example /usr/src/luanti/minetest.conf.example
COPY builtin /usr/src/luanti/builtin
COPY cmake /usr/src/luanti/cmake
COPY doc /usr/src/luanti/doc
COPY fonts /usr/src/luanti/fonts
COPY lib /usr/src/luanti/lib
COPY misc /usr/src/luanti/misc
COPY po /usr/src/luanti/po
COPY src /usr/src/luanti/src
COPY irr /usr/src/luanti/irr
COPY textures /usr/src/luanti/textures

RUN cmake -B build \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DCMAKE_BUILD_TYPE=Release \
        -DRUN_IN_PLACE=FALSE \
        -DBUILD_SERVER=TRUE \
        -DBUILD_CLIENT=TRUE \
        -DENABLE_PROMETHEUS=TRUE \
        -DBUILD_UNITTESTS=FALSE \
        -GNinja && \
    cmake --build build

RUN chown -R root:root /usr/src/pkg-root && \
    chmod -R 755 /usr/src/pkg-root

RUN mkdir -p /usr/src/pkg-root
RUN DESTDIR=/usr/src/pkg-root cmake --install build --prefix /usr
RUN ls -R /usr/src/pkg-root


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