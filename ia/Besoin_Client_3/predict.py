"""
Script final du besoin client 3 : prediction du risque tempete.

Le script charge le modele deja entraine (modele.pkl) et sort la
probabilite qu'un arbre soit a risque ainsi que la decision du systeme
d'alerte. Le modele contient aussi un BallTree de toutes les
coordonnees connues pour qu'on puisse calculer les features spatiales
(nombre de voisins, distance au plus proche) d'un nouvel arbre.

Usage :
  python predict.py --X 1720320 --Y 8294619 \
      --haut_tot 25 --haut_tronc 8 --tronc_diam 150 --age_estim 80 \
      --fk_stadedev vieux --fk_port libre --fk_pied gazon \
      --fk_situation alignement --fk_revetement non \
      --remarquable oui --clc_quartier "centre ville"
"""

import argparse
import joblib
import pandas as pd
from pathlib import Path


def parser_arguments():
    p = argparse.ArgumentParser(description="Prediction du risque tempete pour un arbre")

    # Coordonnees pour le calcul des features spatiales
    p.add_argument("--X", type=float, required=True,
                   help="Coordonnee X en Lambert-93")
    p.add_argument("--Y", type=float, required=True,
                   help="Coordonnee Y en Lambert-93")

    # Variables numeriques obligatoires
    p.add_argument("--haut_tot", type=float, required=True,
                   help="Hauteur totale en metres")
    p.add_argument("--haut_tronc", type=float, required=True,
                   help="Hauteur du tronc en metres")
    p.add_argument("--tronc_diam", type=float, required=True,
                   help="Diametre du tronc en cm")
    p.add_argument("--age_estim", type=float, required=True,
                   help="Age estime en annees")

    # Variables categorielles optionnelles (par defaut "inconnu")
    p.add_argument("--fk_stadedev", default="inconnu")
    p.add_argument("--fk_port", default="inconnu")
    p.add_argument("--fk_pied", default="inconnu")
    p.add_argument("--fk_situation", default="inconnu")
    p.add_argument("--fk_revetement", default="inconnu")
    p.add_argument("--remarquable", default="inconnu")
    p.add_argument("--clc_quartier", default="inconnu")

    return p.parse_args()


def main():
    args = parser_arguments()

    # Chargement du modele sauvegarde
    chemin_modele = Path(__file__).resolve().parent / "modele.pkl"
    modele = joblib.load(chemin_modele)
    pipeline = modele["pipeline"]
    seuil = modele["seuil"]
    balltree = modele["balltree"]

    # Calcul des features spatiales pour ce nouvel arbre.
    # On interroge le BallTree (construit sur tous les arbres connus)
    # pour savoir combien de voisins il y a autour de lui et a quelle
    # distance est le plus proche.
    coord = [[args.X, args.Y]]
    # max(0, n-1) : on soustrait l'arbre lui-meme s'il est dans la base,
    # mais si c'est un arbre tout nouveau on ne descend pas sous zero.
    nb_20 = max(0, int(balltree.query_radius(coord, r=20, count_only=True)[0]) - 1)
    nb_50 = max(0, int(balltree.query_radius(coord, r=50, count_only=True)[0]) - 1)
    nb_100 = max(0, int(balltree.query_radius(coord, r=100, count_only=True)[0]) - 1)
    dist, _ = balltree.query(coord, k=2)
    dist_proche = dist[0, 1]

    # Ratio H/D
    ratio_h_d = args.haut_tot / (args.tronc_diam / 100)

    # Construction de la ligne d'entree
    arbre = pd.DataFrame([{
        "haut_tot": args.haut_tot,
        "haut_tronc": args.haut_tronc,
        "tronc_diam": args.tronc_diam,
        "age_estim": args.age_estim,
        "ratio_h_d": ratio_h_d,
        "nb_voisins_20m": nb_20,
        "nb_voisins_50m": nb_50,
        "nb_voisins_100m": nb_100,
        "dist_plus_proche": dist_proche,
        "fk_stadedev": args.fk_stadedev,
        "fk_port": args.fk_port,
        "fk_pied": args.fk_pied,
        "fk_situation": args.fk_situation,
        "fk_revetement": args.fk_revetement,
        "remarquable": args.remarquable,
        "clc_quartier": args.clc_quartier,
    }])

    proba = pipeline.predict_proba(arbre)[0, 1]
    alerte = proba >= seuil

    print("Resultat de la prediction")
    print("-" * 40)
    print(f"Probabilite de risque : {proba:.3f}")
    print(f"Seuil d'alerte        : {seuil:.3f}")
    print()
    print(f"Features spatiales calculees pour cet arbre :")
    print(f"  voisins dans 20 m  : {nb_20}")
    print(f"  voisins dans 50 m  : {nb_50}")
    print(f"  voisins dans 100 m : {nb_100}")
    print(f"  plus proche voisin : {dist_proche:.1f} m")
    print(f"  ratio H/D          : {ratio_h_d:.1f}")
    print()
    if alerte:
        print(">>> ALERTE : arbre potentiellement a risque")
    else:
        print(">>> Pas d'alerte : arbre considere comme stable")


if __name__ == "__main__":
    main()
