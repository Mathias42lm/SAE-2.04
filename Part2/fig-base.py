import pygame
import random

# Configuration
COULEUR_LIGNE = (185, 65, 55)
COULEUR_FOND = (242, 238, 227)
TAILLE = 4000

MIN_W = 140
MIN_H = 72
MAX_DEPTH = 90

# Initialisation de la surface hors écran
pygame.init()
screen = pygame.Surface((TAILLE, TAILLE))
screen.fill(COULEUR_FOND)

def generate_art(x: int, y: int, w: int, h: int, depth: int):
    """
    Subdivision récursive dessinant directement sur la surface.
    """
    if depth > MAX_DEPTH:
        return

    x_ratio = (x + w / 2.0) / TAILLE
    can_split_v = w > MIN_W
    can_split_h = h > MIN_H

    if not can_split_v and not can_split_h:
        return

    # Probabilités basées sur le gradient X
    p_horizontal = 0.45 * (1.0 - (x_ratio ** 0.9))
    p_vertical = 2

    # Choix de la coupe
    if can_split_v and (not can_split_h or random.random() < p_vertical / (p_vertical + p_horizontal)):
        split_x = x + random.randint(int(w * 0.2), int(w * 0.8))
        # Dessin direct de la ligne verticale
        pygame.draw.line(screen, COULEUR_LIGNE, (split_x, y), (split_x, y + h), 2)
        
        generate_art(x, y, split_x - x, h, depth + 1)
        generate_art(split_x, y, x + w - split_x, h, depth + 1)
    
    elif can_split_h:
        split_y = y + random.randint(int(h * 0.25), int(h * 0.75))
        # Dessin direct de la ligne horizontale
        pygame.draw.line(screen, COULEUR_LIGNE, (x, split_y), (x + w, split_y), 2)
        
        generate_art(x, y, w, split_y - y, depth + 1)
        generate_art(x, split_y, w, y + h - split_y, depth + 1)

# Lancement de la génération
# On laisse une marge de 100 pixels
generate_art(100, 100, TAILLE - 200, TAILLE - 200, 0)

# Sauvegarde
fichier = 'reponse.png'
pygame.image.save(screen, fichier)
print(f"Image sauvegardée sous : {fichier}")