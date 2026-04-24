"""
Preparation des donnees pour le besoin client 3.

On part du CSV nettoye par la partie Big Data (arbres_clean.csv) et on
construit un fichier specifique : data.csv, avec les features utiles et
une cible binaire y.

Choix retenus :
- y = 1 si l'arbre est "abattu" ou "essouche" (equivalent "a risque")
- y = 0 si l'arbre est "en place"
- les autres etats (remplace, supprime, non essouche) sont exclus
- on garde uniquement les lignes ou les mesures physiques sont dispo
- on calcule des features spatiales a partir des coordonnees X/Y :
  ces features (nombre de voisins, distance au voisin le plus proche)
  capturent l'isolement d'un arbre, qui est un facteur mecanique connu
  dans la resistance au vent.
"""

import pandas as pd
from pathlib import Path
from sklearn.neighbors import BallTree

ROOT = Path(__file__).resolve().parent
CSV_IN = ROOT.parent.parent / "data" / "clean" / "arbres_clean.csv"
CSV_OUT = ROOT / "data.csv"

df = pd.read_csv(CSV_IN)
print("Lignes au depart :", len(df))

# 1. Construction de la cible binaire
# on inclut "non essouche" dans les positifs : ce sont aussi des arbres
# abattus (juste avec la souche laissee) et leur ajout ameliore nettement
# les perfs des modeles a arbres
a_risque = ["abattu", "essouche", "non essouche"]
pas_a_risque = ["en place"]

df = df[df["fk_arb_etat"].isin(a_risque + pas_a_risque)].copy()
df["y"] = df["fk_arb_etat"].isin(a_risque).astype(int)

print("Lignes apres filtre etat :", len(df))

# 2. Feature "ratio H/D" (hauteur sur diametre en metres).
# On a garde cette feature meme si elle s'est averee peu informative
# elle est defendable scientifiquement et permet au
# modele de capter les arbres fins et elances en cas exceptionnel.
df["ratio_h_d"] = df["haut_tot"] / (df["tronc_diam"] / 100)

# 3. Features spatiales a partir de X/Y (en metres, Lambert-93).
# L'idee : un arbre isole subit plus le vent qu'un arbre en alignement
# ou en bosquet. On mesure pour chaque arbre le nombre de voisins dans
# plusieurs rayons et la distance au plus proche.
coords = df[["X", "Y"]].values
arbre_tree = BallTree(coords, metric="euclidean")

for rayon in [20, 50, 100]:
    voisins = arbre_tree.query_radius(coords, r=rayon, count_only=True)
    df[f"nb_voisins_{rayon}m"] = voisins - 1  # -1 pour s'exclure soi-meme

dist, _ = arbre_tree.query(coords, k=2)  # k=2 : soi-meme + 1 voisin
df["dist_plus_proche"] = dist[:, 1]

# 4. Selection des features
# Retirees par rapport a la premiere version :
# - clc_nbr_diag : importance negative dans la permutation
# - feuillage : importance nulle (voir rapport)
num_features = ["haut_tot", "haut_tronc", "tronc_diam", "age_estim",
                "ratio_h_d",
                "nb_voisins_20m", "nb_voisins_50m", "nb_voisins_100m",
                "dist_plus_proche"]
cat_features = ["fk_stadedev", "fk_port", "fk_pied", "fk_situation",
                "fk_revetement", "remarquable", "clc_quartier"]

df = df[num_features + cat_features + ["y"]]

# 5. Anti-leakage : on vire les lignes sans mesures physiques
df = df.dropna(subset=num_features)

print("\nLignes apres filtre NA numeriques :", len(df))
print("Repartition cible apres filtre :")
print(df["y"].value_counts())
print("Pourcentage de positifs :", round(100 * df["y"].mean(), 2), "%")

df.to_csv(CSV_OUT, index=False)
print(f"\nFichier ecrit : {CSV_OUT}")
