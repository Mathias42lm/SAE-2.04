# SAE 2.04 – Présentation des 3 parties

Ce dépôt regroupe le travail de la SAE 2.04 en **3 parties principales**.

## Partie 1 – Serveur web et interface

La partie 1 contient une application web (Symfony/PHP + templates Twig) qui permet d’afficher et de lancer des générations visuelles via des scripts Python.

Objectifs principaux :
- mettre en place et adapter un serveur web ;
- proposer une interface pour piloter les figures ;
- intégrer les scripts de génération dans une page web.

Dossier : `Part1/`

## Partie 2 – Génération artistique en Python

La partie 2 contient les scripts Python (Pygame) utilisés pour créer les figures de type art mathématique (inspirées de Georg Nees) et exporter les images générées.

Objectifs principaux :
- implémenter les algorithmes de génération ;
- produire des rendus (images) en haute résolution ;
- préparer les visuels exploités dans la démonstration web.

Dossier : `Part2/`

## Partie 3 – Service réseau avec Docker/Samba

La partie 3 met en place un environnement réseau conteneurisé autour de Samba (AD DC) avec Docker et des scripts d’initialisation.

Objectifs principaux :
- déployer un service Samba dans un conteneur ;
- automatiser le provisionnement avec des scripts shell ;
- structurer la configuration réseau pour les tests de la SAE.

Dossier : `Part3/`

---

Chaque partie peut être consultée séparément via son dossier dédié.
