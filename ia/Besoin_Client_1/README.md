BESOIN CLIENT 1 — Clustering des arbres par taille
===================================================

OBJECTIF
--------
Classer automatiquement les arbres en categories de taille
(petits / moyens / grands) et les afficher sur une carte interactive.

COMMENT CA MARCHE
-----------------
On utilise K-Means : un algorithme qui regroupe des donnees similaires
sans qu'on lui dise a l'avance quoi chercher.
Il se base sur 2 caracteristiques de chaque arbre :
  - haut_tot    : hauteur totale en metres
  - tronc_diam  : diametre du tronc en centimetres

Le notebook (besoin1_clustering.ipynb) teste differents nombres de groupes
(K=2 a 6), mesure la qualite de chaque resultat, puis entraine le modele
final avec K=3 (petits / moyens / grands) comme demande dans la consigne.

Les modeles entraines sont sauvegardes dans models/ pour etre reutilises
sans avoir a tout recalculer.

FICHIERS
--------
  besoin1_clustering.ipynb   exploration + entrainement (a lancer en premier)
  script_besoin1.py          script pour classifier un nouvel arbre
  models/kmeans_k*.pkl       modeles K-Means sauvegardes (k=2, 3, 4)
  models/scaler_besoin1.pkl  normalisation des donnees
  carte_arbres.html          carte interactive (ouvrir dans un navigateur)
  metriques_clustering.png   comparaison des valeurs de K

UTILISATION
-----------
  python script_besoin1.py --haut_tot 8 --tronc_diam 90
  -> Categorie : Arbres moyens

  python script_besoin1.py --haut_tot 20 --tronc_diam 200 --n_clusters 3
  -> Categorie : Grands arbres

  Option --n_clusters : 2, 3 ou 4 (defaut : 3)

PREREQUIS : lancer le notebook avant d'utiliser le script.
