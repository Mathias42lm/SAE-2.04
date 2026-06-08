import sys
import pygame
import random

# --- CONFIGURATION PERSONNELLE ---
COULEUR_BASE = (185, 65, 55)
TAILLE = 4000
MAX_DEPTH = int(sys.argv[1]) # Profondeur maximale aléatoire pour plus de variété 

pygame.init()
screen = pygame.Surface((TAILLE, TAILLE))
screen.fill((242, 238, 227))

def draw_jittered_line(p1, p2, color, intensity=3):
    """Dessine une ligne avec un léger tremblement (imprécision)"""
    # Ajoute un petit décalage aléatoire aux points
    offset = lambda: random.randint(-intensity, intensity)
    start = (p1[0] + offset(), p1[1] + offset())
    end = (p2[0] + offset(), p2[1] + offset())
    pygame.draw.line(screen, color, start, end, 2)

def generate_art_distorted(x, y, w, h, depth):
    # Arrêt précoce aléatoire (Détournement)
    if depth > MAX_DEPTH or (depth > 5 and random.random() < 0.1):
        return

    x_ratio = (x + w / 2.0) / TAILLE
    can_split_v, can_split_h = w > 10, h > 10

    if not can_split_v and not can_split_h:
        return

    # Variation de couleur selon la profondeur
    color_var = max(0, min(255, COULEUR_BASE[0] + (depth * 10)))
    current_color = (color_var, COULEUR_BASE[1], COULEUR_BASE[2])

    p_h = 0.45 * (1.0 - (x_ratio ** 0.7))
    p_v = 0.55

    if can_split_v and (not can_split_h or random.random() < p_v / (p_v + p_h)):
        split = x + random.randint(int(w * 0.1), int(w * 0.9))
        draw_jittered_line((split, y), (split, y + h), current_color)
        generate_art_distorted(x, y, split - x, h, depth + 1)
        generate_art_distorted(split, y, x + w - split, h, depth + 1)
    elif can_split_h:
        split = y + random.randint(int(h * 0.1), int(h * 0.9))
        draw_jittered_line((x, split), (x + w, split), current_color)
        generate_art_distorted(x, y, w, split - y, depth + 1)
        generate_art_distorted(x, split, w, y + h - split, depth + 1)

generate_art_distorted(100, 100, TAILLE - 200, TAILLE - 200, 0)
pygame.image.save(screen, 'creation_personnelle.png')
print("Création détournée sauvegardée.")