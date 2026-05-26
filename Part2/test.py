import pygame
import random
import sys

# Configuration du canevas (Ratio vertical proche de l'original)
WIDTH, HEIGHT = 600, 800
FPS = 30

# Palette de couleurs (Inspirée du papier vieilli et de l'encre d'époque)
BG_COLOR = (242, 238, 227)       # Fond crème/beige
LINE_COLOR = (185, 65, 55)       # Rouge brique / Sienne

# Paramètres de l'algorithme génératif
MIN_WIDTH = 6
MIN_HEIGHT = 12
MAX_DEPTH = 9

def generate_art(x, y, w, h, depth, lines):
    """
    Subdivision récursive de l'espace (BSP) avec gradient de probabilité
    basé sur l'axe X pour imiter le style de Georg Nees.
    """
    if depth > MAX_DEPTH:
        return

    # Normalisation de la position X (0.0 à gauche, 1.0 à droite)
    x_ratio = (x + w / 2.0) / WIDTH

    can_split_v = w > MIN_WIDTH
    can_split_h = h > MIN_HEIGHT

    if not can_split_v and not can_split_h:
        return

    # Détermination du comportement selon le gradient X
    # Plus on est à droite, moins on autorise les coupes horizontales
    p_horizontal = 0.45 * (1.0 - (x_ratio ** 0.7))
    p_vertical = 0.55

    # Choix de la direction de la découpe
    if can_split_v and (not can_split_h or random.random() < p_vertical / (p_vertical + p_horizontal)):
        # Découpe Verticale (Génère un segment vertical)
        # Contrainte pour éviter les lignes trop proches des bords existants (jitter contrôlé)
        split_x = x + random.randint(int(w * 0.2), int(w * 0.8))
        lines.append(((split_x, y), (split_x, y + h)))
        
        # Récursion sur les deux sous-rectangles
        generate_art(x, y, split_x - x, h, depth + 1, lines)
        generate_art(split_x, y, x + w - split_x, h, depth + 1, lines)
    
    elif can_split_h:
        # Découpe Horizontale (Génère un segment horizontal)
        split_y = y + random.randint(int(h * 0.25), int(h * 0.75))
        lines.append(((x, split_y), (x + w, split_y)))
        
        # Récursion sur les deux sous-rectangles
        generate_art(x, y, w, split_y - y, depth + 1, lines)
        generate_art(x, split_y, w, y + h - split_y, depth + 1, lines)

def main():
    pygame.init()
    screen = pygame.display.set_center = pygame.display.set_mode((WIDTH, HEIGHT))
    pygame.display.set_caption("Georg Nees - Untitled (1970) Replica")
    clock = pygame.time.Clock()

    # Conteneur pour stocker les segments de droite : [((x1, y1), (x2, y2)), ...]
    segments = []
    
    # Génération initiale
    generate_art(20, 20, WIDTH - 40, HEIGHT - 40, 0, segments)

    running = True
    while running:
        clock.tick(FPS)
        
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_SPACE:
                    # ESPACE pour régénérer une nouvelle seed de l'œuvre
                    segments.clear()
                    generate_art(20, 20, WIDTH - 40, HEIGHT - 40, 0, segments)
                elif event.key == pygame.K_ESCAPE:
                    running = False

        # Rendu
        screen.fill(BG_COLOR)
        
        # Dessin de tous les segments générés
        for start_pos, end_pos in segments:
            pygame.draw.line(screen, LINE_COLOR, start_pos, end_pos, 1)

        pygame.display.flip()

    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()