# Projet Big Data - Patrimoine arbore de Saint-Quentin

Partie Big Data du projet A3 (FISA4).
Mon perimetre : **Fonctionnalites 1 & 2** (exploration / nettoyage / graphiques).

## Organisation

```
data/raw/      Data_Arbre.csv        donnees brutes
data/clean/    arbres_clean.csv      donnees nettoyees (pour la suite : IA)
scripts/       01_exploration.R      description + diagnostic
               02_nettoyage.R        regles de nettoyage + export
               03_viz.R              graphiques PNG
figures/                             sorties PNG
reports/                             traces texte (exploration + memo nettoyage)
```

## Utilisation

```r
Rscript scripts/01_exploration.R
Rscript scripts/02_nettoyage.R
Rscript scripts/03_viz.R
```

Packages : `tidyverse`, `janitor`, `skimr`, `lubridate`, `stringi`.

## Choix de nettoyage

Decisions prises apres l'exploration (`reports/01_exploration.txt`) :

- **Casse / accents** : modalites saisies de facon incoherente ("Jeune" vs
  "jeune", "Libre" vs "libre"...). Tout passe en minuscules sans accents.
- **"RAS" = NA** : plusieurs colonnes utilisent "RAS" pour dire "rien a
  signaler". Traite comme NA.
- **0 = NA** sur `haut_tot`, `haut_tronc`, `tronc_diam`, `age_estim` : un
  arbre ne peut pas avoir ces valeurs nulles.
- **Aberrations** :
  - `age_estim > 200` -> NA (des lignes contiennent une annee type 2010 a
    la place de l'age).
  - `tronc_diam > 400 cm` -> NA.
  - `haut_tronc > haut_tot` -> NA.
- **Dates** : `dte_plantation == 1970-01-01` (epoch Unix, valeur par
  defaut) -> NA. 86% des plantations ne sont pas renseignees : c'est la
  realite du fichier, pas une erreur.
- **Doublons** : aucun doublon d'`OBJECTID` / `GlobalID`. 74 doublons sur
  (X, Y, nom latin) : probable replantation -> on garde.
- **Lignes sans coordonnees** : 2 lignes supprimees.

Annee de reference pour `age_calc` = **2020** (max observee dans les
dates du fichier).

## Sortie

`data/clean/arbres_clean.csv` : entree pour la partie IA (prediction
`age_estim`, regression logistique "a abattre") et pour la carte
(coordonnees X/Y en Lambert-93 a reprojeter).
