# Official Dart image: https://hub.docker.com/_/dart
# Specify the Dart SDK base image version using dart:<version> (ex: dart:2.14)
FROM bitnami/git:latest

RUN apt-get update -y && DEBIAN_FRONTEND=noninteractive apt-get install -y unzip clang cmake ninja-build pkg-config \
    libgtk-3-dev iproute2 iptables-persistent openresolv

RUN git clone https://git.zx2c4.com/wireguard-tools/ && cd wireguard-tools/src && \
    make && make install

ENV PATH $PATH:$PWD/flutter/bin

# Download and extract Flutter SDK
RUN git clone -b master https://github.com/flutter/flutter.git && flutter doctor

# RUN mkdir /wireguard_linux && cd /wireguard_linux 

WORKDIR /wireguard_linux
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart pub get --offline

# RUN dart pub run ffigen --config ffigen.yaml

EXPOSE 51820/udp