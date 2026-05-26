<?php

namespace App\Controller;

use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Annotation\Route;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\Process\Exception\ProcessFailedException;
use Symfony\Component\Process\Process;

class ArtmathController extends AbstractController
{
    #[Route('/', name: 'racine')]
    public function racine() : Response
    {
        return $this->redirectToRoute('app_artmath');
    }

    #[Route('/artmath', name: 'app_artmath')]
    public function index(): Response
    {
        return $this->render('artmath/index.html.twig');
    }

    #[Route('/figun', name: 'app_fig_un')]
    public function figun(): Response
    {
        return $this->render('artmath/fig_un.html.twig', [
            'fichier' => '',
        ]);
    }

    #[Route('/figdeux', name: 'app_fig_2')]
    public function figdeuxp(): Response
    {
        return $this->render('artmath/fig_deux.html.twig', [
            'fichier' => '',
        ]);
    }

    #[Route('/calculer', name: 'calculer', methods: ['POST'])]
    public function calculer(Request $request): Response
    {
        // Securité : Cast en entier de la dimension
        $dimension = (int) $request->request->get("dimension", 0);
        $calculer  = $request->request->get("calculer");

        $process = new Process(['python3', 'koch.py', $dimension]);
        $process->run();

        if (!$process->isSuccessful()) {
            return new Response("Erreur lors de l'exécution du script Python :<br>" . $process->getErrorOutput());
        }

        // Nettoyage de la sortie standard (enlève les \n potentiels)
        $fichier = trim($process->getOutput());

        if ($calculer !== null) {
            // Correction : retour sur la vue fig_un et non index
            return $this->render('artmath/fig_un.html.twig', [
                'fichier' => $fichier,
            ]);
        }

        return $this->render('artmath/imprimer.html.twig', [
            'fichier' => $fichier,
        ]);
    }

    #[Route('/fig-deux', name: 'fig-deux', methods: ['POST'])]
    public function figdeux(Request $request): Response
    {
        // Securité : Cast des variables pour garantir le typage attendu par Python
        $hasard      = (float) $request->request->get("hasard", 0);
        $hasardangle = (float) $request->request->get("hasardangle", 0);
        $nbcolonnes  = (int) $request->request->get("nbcolonnes", 1);
        $nblignes    = (int) $request->request->get("nblignes", 1);
        $calculer    = $request->request->get("calculer");

        $process = new Process(['python3', 'nees_carre.py', $hasard, $hasardangle, $nbcolonnes, $nblignes]);
        $process->run();

        if (!$process->isSuccessful()) {
            return new Response("Erreur lors de l'exécution du script Python :<br>" . $process->getErrorOutput());
        }

        $fichier = 'reponse.png'; // Ou trim($process->getOutput()) si python renvoie le nom dynamiquement

        if ($calculer !== null) {
            // Correction : retour sur la vue fig_deux et non index
            return $this->render('artmath/fig_deux.html.twig', [
                'fichier' => $fichier,
            ]);
        }

        return $this->render('artmath/imprimer.html.twig', [
            'fichier' => $fichier,
        ]);
    }
}