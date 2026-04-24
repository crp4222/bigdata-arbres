"""
Exemples :
  python script_besoin1.py --haut_tot 8 --tronc_diam 90
  python script_besoin1.py --haut_tot 8 --tronc_diam 90 --n_clusters 2
  python script_besoin1.py --haut_tot 8 --tronc_diam 90 --n_clusters 3
"""

import argparse
import joblib
import numpy as np
import pandas as pd
import os

SCRIPT_DIR  = os.path.dirname(os.path.abspath(__file__))
SCALER_PATH = os.path.join(SCRIPT_DIR, 'models', 'scaler_besoin1.pkl')


def charger_modeles(n_clusters: int):
    kmeans_path = os.path.join(SCRIPT_DIR, 'models', f'kmeans_k{n_clusters}.pkl')
    if not os.path.exists(SCALER_PATH):
        raise FileNotFoundError("Scaler introuvable. Exécutez d'abord le notebook.")
    if not os.path.exists(kmeans_path):
        raise FileNotFoundError(f"Modèle k={n_clusters} introuvable. Exécutez d'abord le notebook.")
    return joblib.load(SCALER_PATH), joblib.load(kmeans_path)


def predire_categorie(haut_tot: float, tronc_diam: float, n_clusters: int) -> str:
    scaler, kmeans = charger_modeles(n_clusters)
    X = pd.DataFrame([[haut_tot, tronc_diam]], columns=['haut_tot', 'tronc_diam'])
    X_scaled = scaler.transform(X)
    cluster = kmeans.predict(X_scaled)[0]

    ordre = np.argsort(kmeans.cluster_centers_[:, 0])
    if n_clusters == 2:
        labels = {ordre[0]: 'Petits arbres', ordre[1]: 'Grands arbres'}
    elif n_clusters == 3:
        labels = {ordre[0]: 'Petits arbres', ordre[1]: 'Arbres moyens', ordre[2]: 'Grands arbres'}
    elif n_clusters == 4:
        labels = {ordre[0]: 'Très petits arbres', ordre[1]: 'Petits arbres',
                  ordre[2]: 'Grands arbres',      ordre[3]: 'Très grands arbres'}
    else:
        labels = {c: f'Cluster {i+1}' for i, c in enumerate(ordre)}
    return labels[cluster]


def main():
    parser = argparse.ArgumentParser(description="Prédit la catégorie de taille d'un arbre.")
    parser.add_argument('--haut_tot',   type=float, required=True, help="Hauteur totale (mètres)")
    parser.add_argument('--tronc_diam', type=float, required=True, help="Diamètre du tronc (cm)")
    parser.add_argument('--n_clusters', type=int, default=3, choices=[2, 3, 4],
                        help="Nombre de catégories (2, 3 ou 4) — défaut : 3")
    args = parser.parse_args()

    categorie = predire_categorie(args.haut_tot, args.tronc_diam, args.n_clusters)

    print(f'\n=== Résultat ===')
    print(f'Hauteur totale  : {args.haut_tot} m')
    print(f'Diamètre tronc  : {args.tronc_diam} cm')
    print(f'Nb catégories   : {args.n_clusters}')
    print(f'Catégorie       : {categorie}')


if __name__ == '__main__':
    main()