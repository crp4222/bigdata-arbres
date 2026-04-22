# Projet Big Data - Patrimoine arbore de Saint-Quentin

Projet sur les arbres de la ville de Saint-Quentin (Aisne) :
exploration, nettoyage, visualisation, carte, correlations, regressions.

## Organisation

```
data/raw/      Data_Arbre.csv        donnees brutes
data/clean/    arbres_clean.csv      donnees nettoyees
scripts/       01_exploration.R      description + diagnostic des donnees
               02_nettoyage.R        regles de nettoyage + export + figures
               04_cartes.R           cartes Leaflet
               05_correlations.R     correlations entre variables
               06_regression.R       regressions lineaire et logistique
figures/                             graphiques PNG generes par 02
reports/       rapport.Rmd / .pdf    rapport final
```

## Utilisation

```r
Rscript scripts/01_exploration.R    # exploration initiale
Rscript scripts/02_nettoyage.R      # genere arbres_clean.csv + figures/
Rscript scripts/04_cartes.R         # cartes
Rscript scripts/05_correlations.R   # correlations
Rscript scripts/06_regression.R     # regressions
```

L'ordre compte : `02_nettoyage.R` doit etre lance avant les scripts 04-06
(ils partent de `arbres_clean.csv`).

Packages utilises : `tidyverse`, `lubridate`, `stringi`, `leaflet`, `sf`.

## Choix de nettoyage (fonctionnalite 1 & 2)

Decisions prises apres l'exploration (`scripts/01_exploration.R`) :

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

`data/clean/arbres_clean.csv` : fichier d'entree pour toutes les
fonctionnalites suivantes (cartes, correlations, regressions).
