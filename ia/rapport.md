# Projet A3 - Partie Intelligence Artificielle

Patrimoine arbore de Saint-Quentin - Trinome Elie / Clement / Victor

---

## Besoin client 1 - Clustering des arbres par taille

### Ce que le client demande

Regrouper les arbres du patrimoine de Saint-Quentin en categories de
taille et les afficher sur une carte interactive. L'objectif est que
le service espaces verts puisse visualiser d'un coup d'oeil la
repartition des grands, moyens et petits arbres sur la ville.

### Pourquoi le clustering et pas une regle manuelle

On aurait pu simplement dire "un arbre en dessous de 8m c'est petit,
au-dessus de 15m c'est grand". Mais ca serait arbitraire. Le
clustering laisse les donnees parler d'elles-memes : l'algorithme
trouve les seuils naturels dans la distribution reelle des arbres de
Saint-Quentin. C'est plus objectif et adapte au patrimoine local.

On a utilise K-Means, qui est l'algorithme de clustering le plus
standard. Il regroupe les points en K groupes en minimisant la
distance de chaque point a son centre de groupe (centroide).

### Choix des variables

On n'a garde que deux variables pour caracteriser la taille :

- `haut_tot` : la hauteur totale en metres
- `tronc_diam` : le diametre du tronc en centimetres

Ces deux variables sont complementaires : un grand arbre a en general
une hauteur elevee ET un gros tronc. On aurait pu ajouter l'age ou
l'espece mais ca aurait melange "taille" et "nature de l'arbre", ce
qui ne correspond pas au besoin.

Apres suppression des lignes sans mesures, on travaille sur
**11 227 arbres**.

### Normalisation obligatoire

K-Means calcule des distances entre points. Sans normalisation,
`tronc_diam` (entre 3 et 395 cm) aurait eu un poids 10 fois plus
grand que `haut_tot` (entre 1 et 37 m) juste parce que ses valeurs
sont plus grandes. Les groupes auraient ete formes presque uniquement
sur le diametre.

On a utilise `StandardScaler` qui ramene chaque variable a une
moyenne de 0 et un ecart-type de 1. Le scaler est sauvegarde avec
le modele pour appliquer exactement la meme transformation sur de
nouveaux arbres.

### Trouver le bon nombre de groupes

On ne savait pas combien de categories creer. On a donc teste K=2 a
K=6 et mesure la qualite avec trois indicateurs :

- **Silhouette** : entre -1 et 1, mesure si chaque arbre est bien
  dans son groupe (proche de ses voisins, loin des autres groupes).
  Plus c'est proche de 1, mieux c'est.
- **Calinski-Harabasz** : ratio entre la dispersion entre groupes et
  la compacite interne. Plus c'est eleve, mieux c'est.
- **Davies-Bouldin** : mesure la confusion entre groupes voisins.
  Plus c'est bas, mieux c'est.

| K   | Inertie | Silhouette | Calinski-Harabasz | Davies-Bouldin |
| --- | ------- | ---------- | ----------------- | -------------- |
| 2   | 9574    | **0.518**  | **15100**         | **0.744**      |
| 3   | 6323    | 0.435      | 14317             | 0.847          |
| 4   | 4914    | 0.424      | 13354             | 0.895          |
| 5   | 3971    | 0.408      | 13058             | 0.868          |
| 6   | 3409    | 0.393      | 12536             | 0.874          |

Les trois indicateurs pointent vers K=2. Mais la consigne demande
explicitement trois categories (petits / moyens / grands) pour
repondre au besoin metier. K=3 reste acceptable avec un Silhouette
a 0.44, ce qui correspond a une separation correcte. C'est un choix
delibere : on ne suit pas aveuglément les metriques quand le besoin
client est clair.

### Resultats du clustering (K=3)

Apres entrainement, on a calcule les caracteristiques moyennes de
chaque groupe pour leur attribuer un nom :

| Categorie     | Hauteur moyenne | Diametre moyen |
| ------------- | --------------- | -------------- |
| Petits arbres | 5.4 m           | 42 cm          |
| Arbres moyens | 9.7 m           | 92 cm          |
| Grands arbres | 17.8 m          | 173 cm         |

Les groupes sont bien distincts et interpretables. Le nommage est
fait automatiquement en triant les clusters par hauteur moyenne
croissante, ce qui garantit que "petits" designe toujours le groupe
le plus bas quelle que soit la numerotation interne de K-Means.

### Carte interactive

Les coordonnees du fichier source sont en projection Lambert (EPSG:3949),
un format cartographique francais en metres. Plotly attend de la
latitude/longitude standard (WGS84). On a converti avec `pyproj`
avant de generer la carte.

Le resultat est un fichier HTML (`carte_arbres.html`) qui s'ouvre
dans n'importe quel navigateur sans installation. Chaque arbre est
represente par un point colore selon sa categorie (vert = petits,
orange = moyens, rouge = grands), avec la hauteur et le diametre
affichables au survol.

### Livrable final

Le script `script_besoin1.py` charge les modeles sauvegardes (`.pkl`)
et classe un nouvel arbre en une fraction de seconde a partir de sa
hauteur et de son diametre :

```
python script_besoin1.py --haut_tot 8 --tronc_diam 90
-> Categorie : Arbres moyens
```

Le script supporte K=2, 3 ou 4 categories selon le besoin.
Les modeles sont sauvegardes une seule fois depuis le notebook et
reutilises sans re-entrainement.

---

## Besoin client 3 - Systeme d'alerte pour les tempetes

### Definir ce qu'on veut predire

Le besoin dit qu'on doit predire les arbres qui risquent d'etre
deracines en cas de tempete. Le probleme c'est que les donnees ne
contiennent pas cette information. La colonne la plus proche c'est
`fk_arb_etat`, qui dit juste si l'arbre est en place, abattu,
essouche, remplace, supprime ou non essouche. On a donc du decider
nous-memes quelles categories correspondent au "risque tempete".

Pour pas decider au hasard, on a regarde les donnees sous deux angles.

**D'abord, les caracteristiques moyennes par categorie.** On a
calcule la taille, le diametre du tronc et l'age moyen de chaque
groupe. Les arbres `essouche` et `abattu` ressortent comme plus
grands et plus vieux que ceux `en place` (un tronc de ~135 cm contre
~93 cm, 45 ans contre 30 ans). Ca colle bien avec des arbres
fragilises. Au passage on remarque que les arbres `remplace` ont
exactement le meme profil que les `en place` (90 cm, 34 ans), donc
c'est surement des remplacements prevus dans le cadre de la gestion
du patrimoine, et pas des arbres tombes.

**Ensuite, on a lu les commentaires textes.** Il y a peu de
commentaires renseignes mais ce qu'on y trouve est tres parlant :

- Sur les 5 commentaires de la categorie `abattu`, 3 parlent
  explicitement de tempete ("tempete du 11.02.2020" deux fois et
  "degat suite tempete du 23 juin 2016"). C'est la preuve la plus
  directe qu'on a du lien entre cette categorie et ce qu'on cherche.
- Cote `essouche`, les commentaires parlent d'arbres "mort" ou
  "deperissant". Pas tempete mais coherent avec une fragilite.
- Cote `supprime` par contre, on trouve plutot "conduite de gaz",
  "amenagement d'arret de bus", "permis de construire". Ce sont
  surtout des suppressions pour travaux, donc rien a voir avec le
  vent.

### Premiere version de la cible

Au depart on a pris :

- classe 1 : `abattu` et `essouche`
- classe 0 : `en place`
- exclus : `remplace`, `supprime` et `non essouche` (on pensait que
  le profil des non essouche ressemblait aux en place).

### On revise : on met les "non essouche" en positifs

Une fois le premier modele en place on a voulu verifier. Un arbre
"non essouche" c'est un arbre coupe dont la souche est restee, donc
c'est aussi un arbre retire et pas un arbre "en place". On a re-entraine
en les comptant comme positifs et on a compare.

| Modele                | AUC-PR sans | AUC-PR avec   | F1 sans | F1 avec       |
| --------------------- | ----------- | ------------- | ------- | ------------- |
| Regression logistique | 0.172       | 0.161         | 0.197   | 0.208         |
| Random Forest         | 0.239       | 0.264 (+10 %) | 0.324   | 0.370 (+14 %) |
| Gradient Boosting     | 0.236       | 0.284 (+20 %) | 0.329   | 0.348         |

Le gain est net sur RF et GB. On a donc garde :

- classe 1 : `abattu`, `essouche`, `non essouche`
- classe 0 : `en place`
- exclus : `remplace` (renouvellement urbain) et `supprime` (travaux)

### Tentative de validation avec les dates d'abattage

Pour renforcer le choix de la cible, on a eu l'idee de croiser les
dates d'abattage avec l'historique des tempetes. Si beaucoup d'arbres
tombaient juste apres une grosse tempete, ca confirmerait notre
choix.

Resultat : les dates ne sont pas precises (presque toutes au 1er ou
au dernier jour du mois, donc saisies groupees) et la saisonnalite
des abattages est concentree en ete (48 % juin-aout) alors que les
tempetes en France sont surtout en hiver. Donc impossible de
corroborer statistiquement. On ne peut pas affirmer que nos positifs
sont des victimes de tempetes, on apprend plutot a reconnaitre
**les arbres que la ville a juge bon de retirer**, toutes causes
confondues. C'est lie au risque tempete mais pas equivalent.

### Tentative d'ajout du ratio H/D

En cherchant des features qui pourraient aider, on est tombe sur un
indicateur utilise en arboriculture : le **ratio d'elancement** H/D
(hauteur divisee par diametre du tronc en metres). L'idee physique :
un arbre haut avec un tronc fin est un levier, il cede plus
facilement au vent.

En regardant les distributions, on a trouve que les arbres "a
risque" ont un H/D **plus faible** que les "non risque" (mediane 11
contre 12), l'inverse de ce que la theorie predit. L'explication est
que nos positifs sont des vieux arbres a gros tronc, donc avec un
ratio faible par construction. On a garde la feature dans le modele
parce qu'elle reste defendable, mais elle ne tire pas le score vers
le haut.

### Preparation des donnees et features finales

Apres la partie analyse, on a construit le jeu final avec :

**Variables numeriques** : haut_tot, haut_tronc, tronc_diam,
age_estim, ratio_h_d.

**Variables categorielles** : fk_stadedev, fk_port, fk_pied,
fk_situation, fk_revetement, remarquable, clc_quartier.

**Un filtre important :** on a vire les arbres sans mesures
physiques. Les arbres `abattu` ou `essouche` ont presque tous leurs
mesures a NA (on ne mesure pas un arbre une fois qu'il est tombe).
Si on laissait comme ca, le modele apprendrait "haut_tot est NA,
donc arbre a risque" et aurait un super score qui ne servirait a
rien en pratique.

**Une bonne idee qui a tout change : les features spatiales.** On
avait les coordonnees X/Y (Lambert-93) dans le jeu de donnees mais
on ne les utilisait pas. On s'est dit qu'un arbre isole subit plus
le vent qu'un arbre dans un alignement serre (l'effet brise-vent est
connu en foresterie). On a donc calcule pour chaque arbre :

- `nb_voisins_20m`, `nb_voisins_50m`, `nb_voisins_100m` : nombre
  d'arbres dans les rayons respectifs, via un `BallTree` scikit-learn.
- `dist_plus_proche` : distance a l'arbre le plus proche.

Au final on part de 11 419 arbres et on termine avec :

- **8 902 arbres exploitables**
- **254 arbres "a risque"** (2.85 %)
- 8 648 arbres "en place"

### Methodologie

On a decoupe les donnees en train (80 %) et test (20 %) de maniere
stratifiee, avec `random_state=42` pour la reproductibilite.

Le pipeline de pretraitement :

- pour les numeriques : `StandardScaler` (centrer, reduire)
- pour les categorielles : `SimpleImputer` (NA -> "inconnu") puis
  `OneHotEncoder` avec `handle_unknown="ignore"`

Tout est encapsule dans un `Pipeline` sklearn pour pouvoir etre
sauvegarde d'un seul bloc dans le fichier `modele.pkl`.

### Comparaison des modeles

On a teste trois classificateurs sur les memes features (cible
revisee, 254 positifs) :

| Modele                | AUC-ROC | AUC-PR | F1 optimal | Precision | Rappel | Alertes |
| --------------------- | ------- | ------ | ---------- | --------- | ------ | ------- |
| Regression logistique | 0.776   | 0.161  | 0.208      | 14 %      | 37 %   | 132     |
| Random Forest         | 0.842   | 0.264  | 0.370      | 32 %      | 43 %   | 68      |
| Gradient Boosting     | 0.851   | 0.284  | 0.348      | 31 %      | 39 %   | 64      |

Le Random Forest et le Gradient Boosting se tiennent de pres, avec
un leger avantage au GB sur l'AUC (ranking global). On l'a choisi
pour la suite.

Note methodologique : on avait commence sans les features spatiales
et nos resultats plafonnaient a F1 = 0.25. L'ajout des features
`nb_voisins_*` et `dist_plus_proche` a nettement ameliore les
resultats, on le voit aussi dans le classement des features plus bas.

### Optimisation des hyperparametres

On a fait une grid search avec validation croisee sur 5 plis
stratifies, scoring `average_precision`. La grille couvrait :

- `n_estimators` : 100, 200, 300
- `max_depth` : 2, 3
- `learning_rate` : 0.01, 0.05
- `min_samples_leaf` : 1, 5, 10, 20
- `subsample` : 0.7, 1.0

On avait fait une premiere grille plus agressive (max_depth jusqu'a
5, learning_rate 0.1) qui donnait un excellent score en CV mais
s'ecroulait sur le test : un cas classique de sur-apprentissage.
Avec seulement ~203 positifs en train, les arbres trop profonds
trouvent des motifs qui n'existent pas.

La grille conservatrice a converge vers :

- `learning_rate = 0.05`, `max_depth = 3`, `n_estimators = 200`
- `min_samples_leaf = 5`, `subsample = 1.0`

### Ensemble calibre

Le GB seul plafonnait a AUC-PR 0.25. On a essaye deux trucs en plus
avant d'abandonner : un ensemble RF + GB (on moyenne les probas) et
une calibration isotonique via `CalibratedClassifierCV`. La
calibration aide parce que le GB sort des probas tres serrees autour
de zero, c'est difficile ensuite de choisir un seuil propre.

Sur le test (1 781 arbres, 51 positifs) :

| Modele                   | AUC-ROC | AUC-PR | F1 optimal |
| ------------------------ | ------- | ------ | ---------- |
| GB seul (grid search)    | 0.853   | 0.252  | 0.351      |
| RF calibre               | 0.857   | 0.260  | 0.374      |
| Ensemble calibre RF + GB | 0.856   | 0.309  | 0.404      |

L'AUC-PR gagne 22 % et le F1 gagne 15 %. On n'a touche ni aux
donnees ni aux features, c'est uniquement du traitement post-modele.

### Deux seuils : urgent et surveillance

Sortir un seul seuil force la ville a choisir entre precision et
rappel. On prefere sortir deux listes :

- **Urgent** (seuil 0.185) : liste courte, a inspecter vite
- **Surveillance** (seuil 0.075) : liste large, a faire avant l'hiver

Ce que ca donne sur le test :

| Liste        | Seuil | Alertes | Vrais positifs | Precision | Rappel |
| ------------ | ----- | ------- | -------------- | --------- | ------ |
| Urgent       | 0.185 | 32      | 15             | 47 %      | 29 %   |
| Surveillance | 0.075 | 157     | 27             | 17 %      | 53 %   |

En cumulant les deux, on capte 27 arbres a risque sur 51, soit 53 %.
C'est le double du rappel d'avant (25 %) sans noyer la ville sous
des alertes inutiles.

En pratique :

- liste urgente : 32 arbres, 15 vrais a inspecter rapidement
- liste surveillance : 157 arbres, a etaler sur l'annee

Ca colle au fonctionnement reel d'un service espaces verts qui a
des priorites differentes selon la saison.

### Importance des features

Le Gradient Boosting fournit un score d'importance pour chaque
feature, base sur la reduction d'impurete pendant l'entrainement
(plus le modele se sert d'une feature pour trancher, plus son score
est eleve).

Top 8 des features les plus utilisees :

| Rang | Feature            | Importance |
| ---- | ------------------ | ---------- |
| 1    | `dist_plus_proche` | 0.17       |
| 2    | `haut_tot`         | 0.12       |
| 3    | `nb_voisins_50m`   | 0.11       |
| 4    | `tronc_diam`       | 0.09       |
| 5    | `haut_tronc`       | 0.07       |
| 6    | `nb_voisins_100m`  | 0.07       |
| 7    | `ratio_h_d`        | 0.06       |
| 8    | `age_estim`        | 0.04       |

Trois des six premieres features sont les features spatiales qu'on
a ajoutees, et la premiere de toutes (`dist_plus_proche`) est
spatiale. Le modele s'appuie d'abord sur l'isolement de l'arbre
avant meme la taille ou l'age. C'est coherent avec l'idee
physique : un arbre isole se prend plus le vent.

**Features retirees du modele final :** `clc_nbr_diag` et `feuillage`
qui n'apportaient aucun signal dans les premieres versions du modele.

Note importante : le jeu de test ne contient que 51 positifs, donc
les chiffres (F1, precision, rappel) sont a prendre avec des
pincettes. Une variation de 2-3 arbres bien ou mal classes peut
faire bouger les scores de quelques points. Les ordres de grandeur
restent neanmoins coherents avec ce qu'on observe en validation
croisee.

### Analyse stratifiee : ou marche le modele ?

On a evalue le modele separement par stade de developpement pour
voir s'il marche uniformement :

| Stade     | n     | Positifs | Precision     | Rappel | F1   |
| --------- | ----- | -------- | ------------- | ------ | ---- |
| adulte    | 1 172 | 40       | 0.55          | 0.28   | 0.37 |
| jeune     | 598   | 9        | 1.00          | 0.11   | 0.20 |
| senescent | peu   | 1        | non evaluable |        |      |
| vieux     | peu   | 1        | non evaluable |        |      |

**Constat :** le modele est fiable sur les arbres **adultes** (F1 =
0.37, precision de 55 %, c'est la grande majorite du patrimoine).
Sur les **jeunes** arbres il reste tres conservateur : il n'en
signale qu'un seul mais il a raison (precision 100 %). Il rate en
revanche 8 positifs sur 9, donc son rappel est tres faible pour
ce stade.

C'est logique : on a entraine le modele sur des profils "d'arbres
retires par la ville", qui sont majoritairement des adultes avec des
gros troncs. Les jeunes arbres a risque ont des caracteristiques
differentes que le modele apprehende mal (il y en a peu dans le
train).

**Conseil operationnel pour le service des espaces verts :**
notre systeme est un outil de surveillance pour les arbres adultes.
Il ne remplace pas une inspection manuelle des jeunes arbres, qui
necessite une expertise arboricole differente.

### Limites du systeme et pistes d'amelioration

On capte la moitie des arbres a risque du patrimoine avec le systeme
a deux niveaux. Les 47 % restants sont inaccessibles avec les
donnees disponibles : ils n'ont aucune signature distinctive dans
les features qu'on a (taille, age, isolement), ce sont des arbres
au profil "moyen" qui ont ete retires pour des raisons qu'on ne
peut pas deviner statistiquement.

Les limites viennent principalement de la donnee, pas du modele :

- **Cible bruitee** : "abattu, essouche ou non essouche" n'est pas
  specifique a la tempete, comme on l'a montre avec les dates et le
  ratio H/D.
- **Peu de positifs** : 203 arbres dans le train, c'est juste.
- **Features insuffisantes** : les vraies causes de deracinement
  (vent local, etat des racines, sol) ne sont pas dans les donnees.

**Pistes pour aller plus loin** :

- Dates d'abattage precises (au jour pres) pour corriger les
  etiquettes via les dates de tempetes connues.
- Mesures locales du vent (rafales max) par quartier ou par rue.
- Informations sur le sol et les racines.
- Historique des tailles et des diagnostics par arbre.

Sans tout ca, on a fait le maximum avec ce qu'on avait. L'ajout des
features spatiales a divise par deux les fausses alertes, et le
passage a l'ensemble calibre avec deux seuils a double le rappel
final (25 % -> 53 %). Le modele remonte maintenant deux listes
exploitables, adaptees aux deux modes de travail du service espaces
verts : urgence et gestion preventive.
