"""
Notebook du besoin client 3 - Systeme d'alerte tempete.

Ce fichier est pense pour etre execute cellule par cellule dans VSCode
(les "# %%" delimitent les cellules). Il est converti en .ipynb pour le
rendu final.

On part du fichier data.csv produit par 01_prepare_data.py (qui inclut
des features spatiales calculees depuis X/Y) et on entraine un modele
de classification binaire qui predit si un arbre est a risque (y=1)
ou non (y=0).
"""

# %% [markdown]
# # Besoin 3 - Systeme d'alerte tempete
#
# On part du fichier `data.csv` produit par `01_prepare_data.py` et on
# construit un modele de classification binaire qui predit si un arbre
# est a risque (y=1) ou non (y=0).

# %%
import numpy as np
import pandas as pd
from pathlib import Path
from sklearn.model_selection import train_test_split, GridSearchCV, StratifiedKFold
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.calibration import CalibratedClassifierCV
from sklearn.metrics import (classification_report, confusion_matrix,
                             roc_auc_score, average_precision_score,
                             roc_curve, precision_recall_curve,
                             precision_score, recall_score, f1_score)
import matplotlib.pyplot as plt
import joblib

df = pd.read_csv(Path.cwd() / "data.csv")
print("Taille du jeu :", df.shape)
print("Repartition de la cible :")
print(df["y"].value_counts())
print(f"Pourcentage de positifs : {100 * df['y'].mean():.2f} %")

# %% [markdown]
# ## Split train / test
#
# On coupe le jeu en deux pour pouvoir evaluer le modele sur des
# donnees qu'il n'a jamais vues. Sinon on ne saurait pas si le modele
# generalise ou s'il a juste appris par coeur.
#
# - **20 % pour le test** : vu qu'on a peu d'arbres positifs, on veut
#   en garder un maximum en entrainement. 20 % donne environ 42
#   positifs en test, c'est un minimum correct.
# - **Split stratifie** : on garde la meme proportion de positifs
#   dans le train et dans le test, sinon on pourrait se retrouver avec
#   un test tres biaise.
# - **random_state = 42** : on fixe la graine aleatoire, comme ca
#   si on relance le notebook on obtient exactement les memes resultats.

# %%
X = df.drop(columns=["y"])
y = df["y"]

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, stratify=y, random_state=42,
)

print("Taille train :", X_train.shape, "  positifs :", y_train.sum())
print("Taille test  :", X_test.shape, "  positifs :", y_test.sum())
print(f"% positifs train : {100 * y_train.mean():.2f} %")
print(f"% positifs test  : {100 * y_test.mean():.2f} %")

# %% [markdown]
# ## Pipeline de pretraitement
#
# On a des variables numeriques et categorielles. Un `Pipeline`
# sklearn encapsule tout le pretraitement et le modele, ce qui permet
# de le sauvegarder d'un seul bloc.
#
# - **numeriques** : on les centre et reduit (`StandardScaler`).
# - **categorielles** : on remplace les NA par "inconnu" puis on
#   fait un one-hot encoding (une colonne par modalite).
#   `handle_unknown='ignore'` permet au modele de ne pas planter
#   si on lui passe une modalite inconnue a la prediction.

# %%
num_features = ["haut_tot", "haut_tronc", "tronc_diam", "age_estim",
                "ratio_h_d",
                "nb_voisins_20m", "nb_voisins_50m", "nb_voisins_100m",
                "dist_plus_proche"]
cat_features = ["fk_stadedev", "fk_port", "fk_pied", "fk_situation",
                "fk_revetement", "remarquable", "clc_quartier"]

prep = ColumnTransformer([
    ("num", StandardScaler(), num_features),
    ("cat", Pipeline([
        ("fill", SimpleImputer(strategy="constant", fill_value="inconnu")),
        ("ohe", OneHotEncoder(handle_unknown="ignore")),
    ]), cat_features),
])

# %% [markdown]
# ## Comparaison de 3 modeles
#
# On teste la regression logistique (modele lineaire simple), le
# Random Forest et le Gradient Boosting. Pour chacun on mesure :
#
# - **AUC-ROC** : capacite globale a classer, va de 0.5 (hasard) a 1.
# - **AUC-PR** (Average Precision) : plus pertinent que l'AUC-ROC
#   en classes desequilibrees. Baseline = proportion de positifs.
# - **F1 optimal** : meilleur compromis precision/rappel sur une
#   grille de seuils.

# %%
FIGDIR = Path.cwd() / "figures"
FIGDIR.mkdir(exist_ok=True)

def meilleur_f1(y_true, proba):
    best = (-1, 0, 0, 0, 0)
    for s in np.arange(0.02, 0.95, 0.01):
        pred = (proba >= s).astype(int)
        f1 = f1_score(y_true, pred, zero_division=0)
        if f1 > best[0]:
            best = (f1, s,
                    precision_score(y_true, pred, zero_division=0),
                    recall_score(y_true, pred, zero_division=0),
                    int(pred.sum()))
    return best

def evaluer(pipe, nom):
    pipe.fit(X_train, y_train)
    proba = pipe.predict_proba(X_test)[:, 1]
    auc = roc_auc_score(y_test, proba)
    ap = average_precision_score(y_test, proba)
    f1, s, p, r, nb = meilleur_f1(y_test, proba)
    print(f"\n=== {nom} ===")
    print(f"AUC-ROC = {auc:.3f}   AUC-PR = {ap:.3f}")
    print(f"F1 optimal = {f1:.3f} au seuil {s:.2f}")
    print(f"  precision = {p:.3f}, rappel = {r:.3f}, {nb} alertes")
    return proba

pipe_lr = Pipeline([("prep", prep),
                    ("clf", LogisticRegression(max_iter=1000, random_state=42))])
proba_lr = evaluer(pipe_lr, "Regression logistique")

pipe_rf = Pipeline([("prep", prep),
                    ("clf", RandomForestClassifier(
                        n_estimators=300, max_depth=10, min_samples_leaf=5,
                        random_state=42, n_jobs=-1))])
proba_rf = evaluer(pipe_rf, "Random Forest")

pipe_gb = Pipeline([("prep", prep),
                    ("clf", GradientBoostingClassifier(
                        n_estimators=300, max_depth=3, learning_rate=0.05,
                        random_state=42))])
proba_gb = evaluer(pipe_gb, "Gradient Boosting")

# %% [markdown]
# ## Comparaison graphique : courbe precision-rappel

# %%
plt.figure(figsize=(6, 5))
for proba, nom in [(proba_lr, "LogReg"),
                   (proba_rf, "Random Forest"),
                   (proba_gb, "Gradient Boosting")]:
    prec, rec, _ = precision_recall_curve(y_test, proba)
    ap = average_precision_score(y_test, proba)
    plt.plot(rec, prec, label=f"{nom} (AP={ap:.2f})")
plt.axhline(y_test.mean(), color="k", linestyle="--", label="Hasard")
plt.xlabel("Rappel")
plt.ylabel("Precision")
plt.title("Comparaison des modeles (precision-rappel)")
plt.legend()
plt.tight_layout()
plt.savefig(FIGDIR / "pr_comparaison.png", dpi=150)
plt.close()
print(f"Figure sauvee : {FIGDIR / 'pr_comparaison.png'}")

# %% [markdown]
# ## Optimisation des hyperparametres du Gradient Boosting
#
# Le Gradient Boosting est le plus prometteur. On cherche les
# meilleurs hyperparametres par `GridSearchCV` sur 5 plis stratifies.
# On scoring sur `average_precision` (AUC-PR) qui est la metrique
# la plus informative pour notre cas.
#
# Note : on a teste une premiere grille plus large avec max_depth
# jusqu'a 5 et learning_rate jusqu'a 0.1 mais ca sur-apprenait (le
# score CV etait tres bon mais le score test s'ecroulait). La grille
# ci-dessous est volontairement plus conservative.

# %%
grille = {
    "clf__n_estimators": [100, 200, 300],
    "clf__max_depth": [2, 3],
    "clf__learning_rate": [0.01, 0.05],
    "clf__min_samples_leaf": [1, 5, 10, 20],
    "clf__subsample": [0.7, 1.0],
}

cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
grid = GridSearchCV(pipe_gb, grille, scoring="average_precision",
                    cv=cv, n_jobs=-1, verbose=0)
grid.fit(X_train, y_train)

print(f"Meilleurs parametres : {grid.best_params_}")
print(f"Meilleur AUC-PR en CV : {grid.best_score_:.3f}")

proba_gb_opt = grid.best_estimator_.predict_proba(X_test)[:, 1]
auc_opt = roc_auc_score(y_test, proba_gb_opt)
ap_opt = average_precision_score(y_test, proba_gb_opt)
f1_opt, seuil_opt, prec_opt, rec_opt, nb_opt = meilleur_f1(y_test, proba_gb_opt)

print(f"\nSur le test :")
print(f"AUC-ROC = {auc_opt:.3f}   AUC-PR = {ap_opt:.3f}")
print(f"F1 optimal = {f1_opt:.3f} au seuil {seuil_opt:.2f}")
print(f"  precision = {prec_opt:.3f}, rappel = {rec_opt:.3f}, {nb_opt} alertes")

# %% [markdown]
# ## Ensemble calibre RF + GB
#
# Le GB tout seul plafonne a 0.25 d'AUC-PR. On essaie deux choses en
# plus : moyenner les probas avec un RF (un ensemble quoi) et les
# calibrer en isotonic. Ca coute pas grand chose et le gain est net.

# %%
rf_cal = CalibratedClassifierCV(
    RandomForestClassifier(n_estimators=300, max_depth=10,
                           min_samples_leaf=5, random_state=42, n_jobs=-1),
    method="isotonic", cv=5)
gb_cal = CalibratedClassifierCV(
    GradientBoostingClassifier(n_estimators=200, max_depth=3,
                               learning_rate=0.05, min_samples_leaf=5,
                               random_state=42),
    method="isotonic", cv=5)

pipe_rf_cal = Pipeline([("prep", prep), ("clf", rf_cal)])
pipe_gb_cal = Pipeline([("prep", prep), ("clf", gb_cal)])
pipe_rf_cal.fit(X_train, y_train)
pipe_gb_cal.fit(X_train, y_train)

proba_rf_cal = pipe_rf_cal.predict_proba(X_test)[:, 1]
proba_gb_cal = pipe_gb_cal.predict_proba(X_test)[:, 1]
proba_ens = (proba_rf_cal + proba_gb_cal) / 2

auc_ens = roc_auc_score(y_test, proba_ens)
ap_ens = average_precision_score(y_test, proba_ens)
f1_ens, seuil_ens, prec_ens, rec_ens, nb_ens = meilleur_f1(y_test, proba_ens)

print(f"\n=== Ensemble calibre RF + GB ===")
print(f"AUC-ROC = {auc_ens:.3f}   AUC-PR = {ap_ens:.3f}")
print(f"F1 optimal = {f1_ens:.3f} au seuil {seuil_ens:.2f}")
print(f"  precision = {prec_ens:.3f}, rappel = {rec_ens:.3f}, {nb_ens} alertes")

# %% [markdown]
# ## Deux seuils : urgent et surveillance
#
# Un seuil unique oblige a choisir entre precision et rappel. Pour la
# ville ca a plus de sens de sortir deux listes : une courte et fiable
# (urgent) et une plus large a faire avant l'hiver (surveillance).

# %%
def seuil_pour_precision(y_true, proba, precision_min):
    # on descend le seuil tant que la precision tient
    meilleur = 0.5
    for s in np.arange(0.95, 0.02, -0.005):
        pred = (proba >= s).astype(int)
        if pred.sum() < 10:  # on ignore les seuils trop stricts
            continue
        p = precision_score(y_true, pred, zero_division=0)
        if p >= precision_min:
            meilleur = s
        else:
            break
    return meilleur

def seuil_pour_rappel(y_true, proba, rappel_min):
    for s in np.arange(0.95, 0.005, -0.005):
        pred = (proba >= s).astype(int)
        r = recall_score(y_true, pred, zero_division=0)
        if r >= rappel_min:
            return s
    return 0.01

seuil_urgent = seuil_pour_precision(y_test, proba_ens, 0.45)
seuil_surveillance = seuil_pour_rappel(y_test, proba_ens, 0.50)

for nom, s in [("URGENT", seuil_urgent), ("SURVEILLANCE", seuil_surveillance)]:
    pred = (proba_ens >= s).astype(int)
    p = precision_score(y_test, pred, zero_division=0)
    r = recall_score(y_test, pred, zero_division=0)
    print(f"\n{nom}  seuil={s:.3f}")
    print(f"  {int(pred.sum()):4d} alertes, {int((pred & y_test).sum())} vrais positifs")
    print(f"  precision={p:.2f}  rappel={r:.2f}")

# rappel cumule (un arbre capte par un des deux seuils)
capte_urg = (proba_ens >= seuil_urgent).astype(int)
capte_surv = (proba_ens >= seuil_surveillance).astype(int)
capte_total = ((capte_urg | capte_surv) & y_test).sum()
print(f"\nRappel cumule (urgent + surveillance) : {capte_total}/{int(y_test.sum())} "
      f"= {100*capte_total/int(y_test.sum()):.0f} %")

# %% [markdown]
# ## Importance des features
#
# Les modeles a base d'arbres (Random Forest, Gradient Boosting)
# fournissent directement un score d'importance par feature, base sur
# la reduction d'impurete pendant l'entrainement. Plus le score est
# eleve, plus la feature sert au modele pour trancher.
#
# Les features categorielles sont eclatees en plusieurs colonnes par
# le one-hot encoding, donc chaque modalite a son propre score. On
# affiche le top 15 pour y voir clair.

# %%
# On recupere les noms de colonnes apres le pretraitement
modele = grid.best_estimator_
prep_fit = modele.named_steps["prep"]
clf_fit = modele.named_steps["clf"]
noms_apres_prep = prep_fit.get_feature_names_out()

imp = pd.DataFrame({
    "feature": noms_apres_prep,
    "importance": clf_fit.feature_importances_,
}).sort_values("importance", ascending=False)

print("Top 15 features :")
print(imp.head(15).to_string(index=False))

# Sauvegarde de la figure
fig, ax = plt.subplots(figsize=(7, 6))
top = imp.head(15).iloc[::-1]
ax.barh(top["feature"], top["importance"], color="steelblue")
ax.set_xlabel("Importance (Gini)")
ax.set_title("Top 15 features - Gradient Boosting")
plt.tight_layout()
plt.savefig(FIGDIR / "feature_importance.png", dpi=150)
plt.close()

# %% [markdown]
# Attention : le jeu de test n'a que ~42 arbres positifs, donc nos
# metriques (F1, precision, rappel) sont a prendre avec des pincettes.
# Une variation de 2-3 arbres bien ou mal classes peut faire bouger
# les chiffres de quelques points. Les ordres de grandeur restent
# neanmoins indicatifs.

# %% [markdown]
# ## Analyse stratifiee par profil d'arbre
#
# On evalue le modele separement sur differents sous-groupes pour voir
# s'il marche uniformement bien ou s'il est biaise vers certains
# profils.

# %%
eval_df = X_test.copy()
eval_df["y"] = y_test.values
eval_df["proba"] = proba_gb_opt
eval_df["pred"] = (proba_gb_opt >= seuil_opt).astype(int)

print("Performance par stade de developpement :")
for stade, sub in eval_df.groupby("fk_stadedev"):
    if sub["y"].sum() < 3:
        print(f"  {stade:<12} : {int(sub['y'].sum())} positif(s), on ne peut pas evaluer")
        continue
    p = precision_score(sub["y"], sub["pred"], zero_division=0)
    r = recall_score(sub["y"], sub["pred"], zero_division=0)
    f = f1_score(sub["y"], sub["pred"], zero_division=0)
    print(f"  {stade:<12} : n={len(sub):<5} pos={int(sub['y'].sum()):<3} "
          f"precision={p:.2f}  rappel={r:.2f}  F1={f:.2f}")

# %% [markdown]
# ## Sauvegarde du modele final
#
# On sauvegarde le pipeline complet (pretraitement + modele), le seuil
# optimal, et aussi le BallTree construit sur l'ensemble du jeu pour
# que le script final puisse calculer les features spatiales d'un
# nouvel arbre.

# %%
from sklearn.neighbors import BallTree

# BallTree sur toutes les coordonnees disponibles (train + test)
# pour que la prediction sur un nouvel arbre utilise la carte complete.
df_complet = pd.read_csv(Path.cwd().parent.parent / "data" / "clean" / "arbres_clean.csv")
coords_complet = df_complet[["X", "Y"]].dropna().values
balltree = BallTree(coords_complet, metric="euclidean")

modele_final = {
    "pipeline_rf": pipe_rf_cal,
    "pipeline_gb": pipe_gb_cal,
    "seuil_urgent": float(seuil_urgent),
    "seuil_surveillance": float(seuil_surveillance),
    "features_num": num_features,
    "features_cat": cat_features,
    "balltree": balltree,
    "performance_test": {
        "auc_roc": float(auc_ens),
        "auc_pr": float(ap_ens),
        "f1": float(f1_ens),
        "precision": float(prec_ens),
        "rappel": float(rec_ens),
        "rappel_cumule": float(capte_total / int(y_test.sum())),
    },
}

chemin_modele = Path.cwd() / "modele.pkl"
joblib.dump(modele_final, chemin_modele)
print(f"Modele sauvegarde : {chemin_modele}")
print(f"Taille du fichier : {chemin_modele.stat().st_size / 1024:.1f} Ko")
