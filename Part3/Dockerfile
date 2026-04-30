FROM ubuntu:latest

ENV DEBIAN_FRONTEND=noninteractive
# Installation des paquets (Q3) en une seule couche + optimisation
RUN apt update && apt install -y \
    samba \
    smbclient \
    cifs-utils \
    nano \
    vim \
    net-tools \
    iputils-ping \
    iproute2 \
    winbind\
    libnss-winbind\
    && rm -rf /var/lib/apt/lists/* # Nettoyage du cache pour réduire la taille de l'image