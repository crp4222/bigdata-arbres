# README – Utilisation du script `predict.py`

## 📌 Description

Ce script permet de prédire l’âge d’un arbre à partir de ses caractéristiques physiques et de son stade de développement.

Il utilise trois modèles de machine learning pré-entraînés :

* Régression linéaire
* Arbre de décision
* Random Forest

Le script affiche une prédiction d’âge pour chacun de ces modèles.

---

## 📂 Prérequis

Avant d’exécuter le script, assurez-vous d’avoir :

### 1. Python

* Python 3.8 ou supérieur

### 2. Dépendances Python

Installez les bibliothèques nécessaires :

```bash
pip install numpy pandas joblib scikit-learn
```

Note : scikit-learn doit être dans la version 1.6.1

### 3. Fichiers requis

Les fichiers suivants doivent être présents dans le même dossier que `predict.py` :

* `linear_regression.pkl`
* `decision_tree.pkl`
* `random_forest.pkl`
* `scaler.pkl`
* `encoder.pkl`

---

## 🚀 Utilisation

Le script se lance en ligne de commande avec des arguments obligatoires :

### Arguments requis

| Argument        | Type   | Description                                                      |
| --------------- | ------ | ---------------------------------------------------------------- |
| `--haut_tot`    | float  | Hauteur totale de l’arbre (en mètres)                            |
| `--haut_tronc`  | float  | Hauteur du tronc (en mètres)                                     |
| `--tronc_diam`  | float  | Diamètre du tronc (en cm)                                        |
| `--fk_stadedev` | string | Stade de développement (`adulte`, `jeune`, `senescent`, `vieux`) |

---

## 🧪 Exemple d’exécution

```bash
python predict.py --haut_tot 7 --haut_tronc 2 --tronc_diam 48 --fk_stadedev jeune
```

### Exemple de sortie

```text
Âge prédit par Linear Regression : 15.00
Âge prédit par Decision Tree : 16.65
Âge prédit par Random Forest : 16.43
```

---

## ⚙️ Fonctionnement interne

1. Les arguments sont récupérés via `argparse`.
2. Le stade de développement est converti en valeur numérique.
3. Les données sont mises en forme dans un DataFrame.
4. Les features sont normalisées avec un scaler pré-entraîné.
5. Chaque modèle prédit l’âge de l’arbre.
6. Les résultats sont affichés dans la console.

---

## ⚠️ Remarques

* Les valeurs doivent être cohérentes (ex : pas de hauteur négative).
* Le paramètre `fk_stadedev` doit être parmi :

  * `adulte`
  * `jeune`
  * `senescent`
  * `vieux`
* Toute valeur inconnue peut provoquer une erreur ou un comportement inattendu.

---

## 📎 Structure du projet

```
/project
│
├── predict.py
├── linear_regression.pkl
├── decision_tree.pkl
├── random_forest.pkl
├── scaler.pkl
├── encoder.pkl
└── README.txt
```

---

## 👨‍💻 Auteur

Clément TERRIER - Chargé du besoin du client 2.

---

## ✅ Résumé

Ce script permet une utilisation simple en ligne de commande pour obtenir rapidement une estimation de l’âge d’un arbre à partir de quelques mesures.
