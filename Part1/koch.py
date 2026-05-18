#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Calcule la courbe de Von Koch et enregistre la dans un fichier png
Crée le Lundi 28 Février 2022

Exemple : python3 koch.py 3
Crée un fichier png et retourne le nom de ce fichier

Principe : http://math.univ-lyon1.fr/irem/Formation_ISN/formation_recursivite/tortue/vonkoch.html

@author: Frédéric BONNARDOT, All rights reserved
This code is given as is without warranty of any kind.
In no event shall the authors or copyright holder be liable for any claim damages or other liability.

"""
# Pour installer le paquet matplotlib :
# apt install python3-pip
# apt install python3-matplotlib

import sys # Pour récupérer les paramètres passés en ligne de commande
import matplotlib.pyplot as plt
import math

def motif(fig,dim,x1,y1,x2,y2):
    if dim==0:
        # Dimension = 0 -> trace une droite
        plt.plot([x1,x2],[y1,y2])
    else:
        # Sinon partage en 4 sections
        deltax=(x2-x1)/3
        deltay=(y2-y1)/3
        xa=x1+deltax
        ya=y1+deltay
        xb=xa+deltax*0.5-deltay*math.sqrt(3)/2
        yb=ya+deltax*math.sqrt(3)/2+deltay*0.5
        xc=x2-deltax
        yc=y2-deltay

        motif(fig,dim-1,x1,y1,xa,ya)
        motif(fig,dim-1,xa,ya,xb,yb)
        motif(fig,dim-1,xb,yb,xc,yc)
        motif(fig,dim-1,xc,yc,x2,y2)

dimension=int(sys.argv[1]) # Premier paramètre : dimension que l'on convertit en entier

# Dessine l
fig=plt.figure();
motif(fig,dimension,0,0,1,0)

# Enregistre la figure
fichier='reponse.svg'
fig.savefig(fichier)
# Ecrit le nom du fichier pour celui qui appelle ce programme
print (fichier)