===============================================================
Besoin client 3 - Systeme d'alerte pour les tempetes
===============================================================

Contenu du dossier
------------------
- data.csv               : jeu de donnees utilise (issu du nettoyage Big Data)
- 01_prepare_data.py     : script qui produit data.csv
- notebook.py            : notebook source (cellules delimitees par "# %%")
- notebook.ipynb         : notebook execute avec outputs (livrable)
- modele.pkl             : modele final entraine + seuil + BallTree
- predict.py             : script final CLI pour predire sur un nouvel arbre
- figures/               : courbes ROC / precision-rappel / importance
- README.txt             : ce fichier


Utilisation du script final predict.py
--------------------------------------
Le script prend les caracteristiques d'un arbre en arguments et renvoie
la probabilite de risque ainsi que la decision d'alerte. Il calcule
automatiquement les features spatiales (nombre de voisins, distance au
plus proche) a partir des coordonnees X/Y.

Exemple d'arbre a risque :

  python predict.py \
      --X 1720320 --Y 8294619 \
      --haut_tot 25 --haut_tronc 8 --tronc_diam 150 --age_estim 80 \
      --fk_stadedev vieux --fk_port libre --fk_pied gazon \
      --fk_situation alignement --fk_revetement non \
      --remarquable oui --clc_quartier "centre ville"

Sortie attendue :
  Probabilite de risque : <0.16 ou plus>
  Seuil d'alerte        : 0.160
  Features spatiales calculees pour cet arbre :
    voisins dans 20 m  : ...
    ...
  >>> ALERTE : arbre potentiellement a risque


Arguments obligatoires
----------------------
Coordonnees (pour le calcul des features spatiales) :
  --X       Coordonnee X en Lambert-93
  --Y       Coordonnee Y en Lambert-93

Mesures physiques :
  --haut_tot      Hauteur totale en metres
  --haut_tronc    Hauteur du tronc en metres
  --tronc_diam    Diametre du tronc en cm
  --age_estim     Age estime en annees


Arguments optionnels (par defaut "inconnu")
-------------------------------------------
  --fk_stadedev       Stade de developpement (jeune, adulte, vieux...)
  --fk_port           Port de l'arbre
  --fk_pied           Type de pied
  --fk_situation      Situation (alignement, isole...)
  --fk_revetement     Presence d'un revetement
  --remarquable       Arbre remarquable (oui / non)
  --clc_quartier      Quartier de Saint-Quentin


Packages requis
---------------
  pip install pandas scikit-learn joblib numpy

Note : le script ne relance aucun entrainement. Il charge directement
modele.pkl qui contient le pipeline complet et le BallTree des
coordonnees connues.
