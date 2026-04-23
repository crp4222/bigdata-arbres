=====================================
 BESOIN CLIENT 1 — Visualisation sur carte
 Clustering des arbres par taille (K-Means)
=====================================

DESCRIPTION
-----------
Ce dossier contient le code pour regrouper les arbres du patrimoine de
Saint-Quentin en catégories de taille (petits / moyens / grands) via
un algorithme de clustering K-Means, et les afficher sur une carte interactive.

FICHIERS
--------
  besoin1_clustering.ipynb   -> Notebook complet (exploration + entraînement)
  script_besoin1.py          -> Script ligne de commande (utilise les modèles sauvegardés)
  models/
    kmeans_besoin1.pkl       -> Modèle K-Means entraîné (k=3)
    scaler_besoin1.pkl       -> StandardScaler (normalisation)
  arbres_clean.csv           -> Données utilisées
  carte_arbres.html          -> Carte interactive générée
  metriques_clustering.png   -> Graphiques des métriques

UTILISATION DU SCRIPT
---------------------
Prérequis : Python 3, scikit-learn, joblib, numpy, pandas

  python script_besoin1.py --haut_tot <hauteur_m> --tronc_diam <diametre_cm>

EXEMPLES
--------
  # Arbre de 8m de haut, tronc de 90cm de diamètre
  python script_besoin1.py --haut_tot 8 --tronc_diam 90
  -> Catégorie : Arbres moyens

  # Grand arbre de 20m, gros tronc
  python script_besoin1.py --haut_tot 20 --tronc_diam 200
  -> Catégorie : Grands arbres

  # Petit arbre
  python script_besoin1.py --haut_tot 4 --tronc_diam 30
  -> Catégorie : Petits arbres

PARAMÈTRES
----------
  --haut_tot    Hauteur totale de l'arbre en mètres  (ex: 8.5)
  --tronc_diam  Diamètre du tronc en centimètres     (ex: 90)

MÉTRIQUES (k=3)
---------------
  Silhouette Score   : 0.4352
  Calinski-Harabasz  : 14316.9
  Davies-Bouldin     : 0.8473

NOTE
----
Le script ne ré-entraîne PAS le modèle à chaque appel.
Il charge uniquement les fichiers .pkl pré-entraînés.
