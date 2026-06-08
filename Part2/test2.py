import pygame
import random

# --- CONFIGURATION ---
COULEUR_BASE = (185, 65, 55)
TAILLE = 4000
MIN_W, MIN_H = 10, 10 # Seuil de subdivision minimale

pygame.init()
screen = pygame.Surface((TAILLE, TAILLE))
screen.fill((242, 238, 227))

def draw_distorted_line(start_pos, end_pos, color, depth):
    """
    Dessine une ligne avec épaisseur variable et un effet de 'trous' 
    pour éviter les lignes trop parfaites.
    """
    # 1. Épaisseur variable : épais au début (0), fin à la fin
    thickness = max(1, 4 - (depth // 2))
    
    # 2. Effet "Détournement" : Probabilité de ne pas tracer la ligne complète (20%)
    if random.random() < 0.2:
        return 

    # 3. Jitter léger
    offset = random.randint(-1, 1)
    p1 = (start_pos[0] + offset, start_pos[1] + offset)
    p2 = (end_pos[0] + offset, end_pos[1] + offset)
    
    pygame.draw.line(screen, color, p1, p2, thickness)

def generate_art_dense(x, y, w, h, depth):
    # Condition d'arrêt réelle : quand on ne peut plus diviser
    if w < MIN_W or h < MIN_H:
        return

    x_ratio = (x + w / 2.0) / TAILLE
    
    # Variation de couleur : dégradé selon X et Profondeur
    red_var = max(0, min(255, COULEUR_BASE[0] + (depth * 5)))
    current_color = (red_var, COULEUR_BASE[1], COULEUR_BASE[2])

    # Logique de split (Nees style avec biais)
    p_h = 0.45 * (1.0 - (x_ratio ** 0.7))
    p_v = 0.55

    # Choix du split
    if random.random() < p_v / (p_v + p_h):
        # Vertical Split
        split = x + random.randint(int(w * 0.2), int(w * 0.8))
        draw_distorted_line((split, y), (split, y + h), current_color, depth)
        generate_art_dense(x, y, split - x, h, depth + 1)
        generate_art_dense(split, y, x + w - split, h, depth + 1)
    else:
        # Horizontal Split
        split = y + random.randint(int(h * 0.25), int(h * 0.75))
        draw_distorted_line((x, split), (x + w, split), current_color, depth)
        generate_art_dense(x, y, w, split - y, depth + 1)
        generate_art_dense(x, split, w, y + h - split, depth + 1)

# Lancement
generate_art_dense(50, 50, TAILLE - 100, TAILLE - 100, 0)
pygame.image.save(screen, 'creation_dense.png')
print("Génération densité maximale terminée.")