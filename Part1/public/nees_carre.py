#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Calcule les carré de nees et enregistre la dans un fichier png
Crée le Lundi 28 Février 2022 - Jeudi 5 Mai 2022

Exemple : python3 nees_carre.py 0.75 0.5 8 10
Crée un fichier png et retourne le nom de ce fichier

@author: Frédéric BONNARDOT Noel ANDRE, All rights reserved
This code is given as is without warranty of any kind.
In no event shall the authors or copyright holder be liable for any claim damages or other liability.

"""
# Utilise pygame, random, math :
#   apt install python3-pygame
#   pip3 install pygame
# Attention: il faut un linux avec une interface graphique d'installé
#   car on utilise sdl, un simple terminal ne marche pas avec pygame.

import sys 		# Pour récupérer les paramètres passés en ligne de commande
from math import *	# Importe toutes les fonctions de math (cos, ...)
import random		# Pour tirer des nombres au hasard
import pygame		# Pour les graphismes

# Récupère les paramètres
# Premier paramètre : amplitude du hasard entre 0 et 1
# replace permet de transformer 5,4 en 5.4 car python attend un . pour les flottants
hasard=float(sys.argv[1].replace(',','.'))
# Amplitude des rotations entre 0 et 1
hasardangle=float(sys.argv[2].replace(',','.'))
# Nombre de lignes et de colonnes nombres entiers
nbcolonnes=int(sys.argv[3])
nblignes=int(sys.argv[4])

# Paramètres figés dans le programme
taille=80 # Taille d'un carré
rempli=1 # Remplissage du carré

# Taille de la zone pour dessiner
larg=taille*(nbcolonnes+2)
haut=taille*(nblignes+2)

# Initialise pygame
pygame.init()

# Crée un surface blanche où dessiner
screen = pygame.surface.Surface((larg,haut))
pygame.draw.rect(screen,(255,255,255),(0,0,larg,haut))
#screen.fill((124,125,125))

# On dessine les carrés
for i in range(nbcolonnes):
    for j in range(nblignes):
         angle=pi/4+(random.random()-0.5)*(hasardangle*j/nblignes*1.5)**3
         x0=taille+taille*(i+(random.random()-0.5)*(hasard*j/nblignes*1.5)**3)
         y0=taille+taille*(j+(random.random()-0.5)*(hasard*j/nblignes*1.5)**3)
         x1=x0+sqrt(2)/2*taille*cos(angle)
         y1=y0+sqrt(2)/2*taille*sin(angle)
         x2=x0-sqrt(2)/2*taille*sin(angle)
         y2=y0+sqrt(2)/2*taille*cos(angle)
         x3=x0-sqrt(2)/2*taille*cos(angle)
         y3=y0-sqrt(2)/2*taille*sin(angle)
         x4=x0+sqrt(2)/2*taille*sin(angle)
         y4=y0-sqrt(2)/2*taille*cos(angle)
         pygame.draw.polygon(screen,(0,0,0),((x1,y1),(x2,y2),(x3,y3),(x4,y4)),rempli)

# Enregistre la figure
fichier='reponse.png'
pygame.image.save(screen,fichier)

# Ecrit le nom du fichier pour celui qui appelle ce programme
print (fichier)
