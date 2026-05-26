import pygame
import random

# --- CONFIGURATION REPLICA ---
COULEUR_LIGNE = (185, 65, 55)
COULEUR_FOND = (242, 238, 227)
TAILLE = 4000
MIN_W, MIN_H = 6, 12
MAX_DEPTH = 9

pygame.init()
screen = pygame.Surface((TAILLE, TAILLE))
screen.fill(COULEUR_FOND)

def generate_nees_replica(x, y, w, h, depth):
    if depth > MAX_DEPTH:
        return

    x_ratio = (x + w / 2.0) / TAILLE
    can_split_v, can_split_h = w > MIN_W, h > MIN_H

    if not can_split_v and not can_split_h:
        return

    p_h = 0.45 * (1.0 - (x_ratio ** 0.7))
    p_v = 0.55

    # Choix strict de la direction
    if can_split_v and (not can_split_h or random.random() < p_v / (p_v + p_h)):
        split = x + random.randint(int(w * 0.2), int(w * 0.8))
        pygame.draw.line(screen, COULEUR_LIGNE, (split, y), (split, y + h), 2)
        generate_nees_replica(x, y, split - x, h, depth + 1)
        generate_nees_replica(split, y, x + w - split, h, depth + 1)
    elif can_split_h:
        split = y + random.randint(int(h * 0.25), int(h * 0.75))
        pygame.draw.line(screen, COULEUR_LIGNE, (x, split), (x + w, split), 2)
        generate_nees_replica(x, y, w, split - y, depth + 1)
        generate_nees_replica(x, split, w, y + h - split, depth + 1)

generate_nees_replica(100, 100, TAILLE - 200, TAILLE - 200, 0)
pygame.image.save(screen, 'nees_replica.png')
print("Replica sauvegardée.")