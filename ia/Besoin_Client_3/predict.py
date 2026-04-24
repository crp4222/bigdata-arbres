"""
Prediction du risque tempete pour un arbre.

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
    p.add_argument("--X", type=float, required=True)
    p.add_argument("--Y", type=float, required=True)
    p.add_argument("--haut_tot", type=float, required=True)
    p.add_argument("--haut_tronc", type=float, required=True)
    p.add_argument("--tronc_diam", type=float, required=True)
    p.add_argument("--age_estim", type=float, required=True)
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

    modele = joblib.load(Path(__file__).resolve().parent / "modele.pkl")
    pipe_rf = modele["pipeline_rf"]
    pipe_gb = modele["pipeline_gb"]
    seuil_urgent = modele["seuil_urgent"]
    seuil_surveillance = modele["seuil_surveillance"]
    balltree = modele["balltree"]

    coord = [[args.X, args.Y]]
    nb_20 = max(0, int(balltree.query_radius(coord, r=20, count_only=True)[0]) - 1)
    nb_50 = max(0, int(balltree.query_radius(coord, r=50, count_only=True)[0]) - 1)
    nb_100 = max(0, int(balltree.query_radius(coord, r=100, count_only=True)[0]) - 1)
    dist, _ = balltree.query(coord, k=2)
    dist_proche = dist[0, 1]

    ratio_h_d = args.haut_tot / (args.tronc_diam / 100)

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

    # ensemble : moyenne des probas RF calibre et GB calibre
    p_rf = pipe_rf.predict_proba(arbre)[0, 1]
    p_gb = pipe_gb.predict_proba(arbre)[0, 1]
    proba = (p_rf + p_gb) / 2

    if proba >= seuil_urgent:
        niveau = "URGENT"
        consigne = "a inspecter en priorite (sous 48h)"
    elif proba >= seuil_surveillance:
        niveau = "SURVEILLANCE"
        consigne = "a inspecter avant la saison des tempetes"
    else:
        niveau = "PAS D'ALERTE"
        consigne = "arbre considere comme stable"

    print("Resultat de la prediction")
    print("-" * 40)
    print(f"Probabilite de risque : {proba:.3f}")
    print(f"Seuil urgent          : {seuil_urgent:.3f}")
    print(f"Seuil surveillance    : {seuil_surveillance:.3f}")
    print()
    print(f"Features spatiales :")
    print(f"  voisins dans 20 m  : {nb_20}")
    print(f"  voisins dans 50 m  : {nb_50}")
    print(f"  voisins dans 100 m : {nb_100}")
    print(f"  plus proche voisin : {dist_proche:.1f} m")
    print(f"  ratio H/D          : {ratio_h_d:.1f}")
    print()
    print(f">>> {niveau} : {consigne}")


if __name__ == "__main__":
    main()
