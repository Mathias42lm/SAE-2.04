FROM ubuntu:latest

ENV DEBIAN_FRONTEND=noninteractive

# Installation des paquets (ajout de samba-ad-dc)
RUN apt update && apt install -y \
    samba \
    acl \
    smbclient \
    cifs-utils \
    nano \
    vim \
    net-tools \
    iputils-ping \
    iproute2 \
    winbind \
    libnss-winbind \
    samba-ad-provision \
    samba-dsdb-modules \
    samba-vfs-modules \
    samba-ad-dc \
    && rm -rf /var/lib/apt/lists/*

# Copie de l'orchestrateur ET du dossier des sous-scripts
COPY ./linux/l-start.sh /ok.sh
COPY ./cmd /cmd

# Application des droits d'exécution en une seule couche
RUN chmod +x /ok.sh && \
    chmod +x /cmd/*.sh

# Ports nécessaires pour Samba en mode AD DC
EXPOSE 53 88 135 137 138 139 389 445 464 636 3268 3269

ENTRYPOINT ["/ok.sh"]