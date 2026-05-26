FROM ubuntu:latest

ENV DEBIAN_FRONTEND=noninteractive

# Installation des paquets et nettoyage du cache
RUN apt update && apt install -y \
    samba \
    smbclient \
    cifs-utils \
    nano \
    vim \
    net-tools \
    iputils-ping \
    iproute2 \
    winbind \
    libnss-winbind \
    && rm -rf /var/lib/apt/lists/*

# Copie de l'orchestrateur ET du dossier des sous-scripts
COPY ./ok.sh /ok.sh
COPY ./cmd /cmd

# Application des droits d'exécution en une seule couche
RUN chmod +x /ok.sh && \
    chmod +x /cmd/*.sh

# Ports nécessaires pour Samba en mode AD DC
EXPOSE 53 88 135 137 138 139 389 445 464 636 3268 3269

ENTRYPOINT ["/ok.sh"]