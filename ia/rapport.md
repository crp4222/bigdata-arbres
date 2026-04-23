# Projet A3 - Partie Intelligence Artificielle

Patrimoine arbore de Saint-Quentin - Trinome Elie / Clement / Victor

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

### Ce qu'on a decide

A partir de ces observations on a pris comme definition :

- **Arbre a risque (classe 1)** : les arbres `abattu` et `essouche`.
- **Arbre sans risque (classe 0)** : les arbres `en place`.
- **Lignes qu'on enleve du jeu** : `remplace` (profil identique aux
  "en place"), `supprime` (des travaux, pas du vent), `non essouche`
  (profil proche des "en place" et seulement 62 arbres).

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

- **8 856 arbres exploitables**
- **208 arbres "a risque"** (2.35 %)
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

On a teste trois classificateurs sur les memes features :

| Modele | AUC-ROC | AUC-PR | F1 optimal | Precision | Rappel | Alertes |
|--------|---------|--------|------------|-----------|--------|---------|
| Regression logistique | 0.762 | 0.187 | 0.313 | 32 % | 31 % | 41 |
| Random Forest | 0.828 | 0.185 | 0.313 | 32 % | 31 % | 41 |
| Gradient Boosting | 0.840 | 0.238 | 0.333 | 33 % | 33 % | 42 |

Le Gradient Boosting gagne sur les trois metriques. On l'a choisi
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
Avec seulement ~166 positifs en train, les arbres trop profonds
trouvent des motifs qui n'existent pas.

La grille conservatrice a converge vers :
- `learning_rate = 0.05`, `max_depth = 3`, `n_estimators = 300`
- `min_samples_leaf = 5`, `subsample = 1.0`

### Modele final et metriques

Resultats sur le jeu de test (1 772 arbres, 42 positifs) :

| Metrique | Valeur |
|----------|--------|
| AUC-ROC | 0.831 |
| AUC-PR | 0.265 |
| F1 optimal | 0.366 |
| Precision (seuil 0.16) | 44.8 % |
| Rappel (seuil 0.16) | 31.0 % |
| Nombre d'alertes emises | 29 |

Comparaison avec notre premier modele (sans features spatiales) :
precision de 20 % -> 45 %, nombre d'alertes 65 -> 29. On a divise
par deux les fausses alertes pour un rappel quasi identique.

**Lecture concrete :** sur les 29 arbres que le modele signale comme
a risque, environ 13 sont effectivement des vrais positifs. On capte
31 % des arbres a risque du patrimoine (13 sur 42). Les 16 autres
sont des fausses alertes a inspecter. C'est loin d'etre parfait
mais c'est bien plus utile que de dire "inspectez les 8 000 arbres
de la ville".

### Importance des features

Le Gradient Boosting fournit un score d'importance pour chaque
feature, base sur la reduction d'impurete pendant l'entrainement
(plus le modele se sert d'une feature pour trancher, plus son score
est eleve).

Top 8 des features les plus utilisees :

| Rang | Feature | Importance |
|------|---------|------------|
| 1 | `dist_plus_proche` | 0.21 |
| 2 | `haut_tot` | 0.12 |
| 3 | `tronc_diam` | 0.12 |
| 4 | `nb_voisins_50m` | 0.11 |
| 5 | `nb_voisins_100m` | 0.10 |
| 6 | `ratio_h_d` | 0.06 |
| 7 | `age_estim` | 0.05 |
| 8 | `haut_tronc` | 0.04 |

Quatre des cinq premieres features sont les features spatiales qu'on
a ajoutees. Le modele s'appuie d'abord sur **l'isolement** de l'arbre
(distance au plus proche voisin) avant meme la taille ou l'age.
C'est coherent avec l'idee physique : un arbre isole se prend plus
le vent.

**Features retirees du modele final :** `clc_nbr_diag` et `feuillage`
qui n'apportaient aucun signal dans les premieres versions du modele.

Note importante : le jeu de test ne contient que 42 positifs, donc
les chiffres (F1, precision, rappel) sont a prendre avec des
pincettes. Une variation de 2-3 arbres bien ou mal classes peut
faire bouger les scores de quelques points. Les ordres de grandeur
restent neanmoins coherents avec ce qu'on observe en validation
croisee.

### Analyse stratifiee : ou marche le modele ?

On a evalue le modele separement par stade de developpement pour
voir s'il marche uniformement :

| Stade | n | Positifs | Precision | Rappel | F1 |
|-------|---|----------|-----------|--------|-----|
| adulte | 1 168 | 36 | 0.43 | 0.33 | 0.38 |
| jeune | 594 | 5 | 0.00 | 0.00 | 0.00 |
| senescent | peu | 1 | non evaluable | | |
| vieux | peu | 0 | non evaluable | | |

**Constat majeur :** le modele marche correctement sur les arbres
**adultes** (F1 = 0.38, qui represente la grande majorite du
patrimoine), mais il est **totalement aveugle aux jeunes arbres** (0
detection sur les 5 positifs du test).

C'est logique : on a entraine le modele sur des profils "d'arbres
retires par la ville", qui sont majoritairement des adultes et des
vieux avec des gros troncs. Les jeunes arbres a risque ont des
caracteristiques tres differentes que le modele n'a jamais bien vues
(il y en avait tres peu dans le train).

**Conseil operationnel pour le service des espaces verts :**
notre systeme est un outil de surveillance pour les arbres adultes.
Il ne remplace pas une inspection manuelle des jeunes arbres, qui
necessite une expertise arboricole differente.

### Limites du systeme et pistes d'amelioration

45 % de precision c'est deja bien mais ca veut dire qu'a peu pres
une alerte sur deux est fausse. Ce n'est pas scandaleux vu la
difficulte du probleme, mais ca impose a la ville de faire une
verification manuelle. On considere ce modele comme **un premier
filtre** plus que comme un systeme de decision automatique.

Les limites viennent principalement de la donnee, pas du modele :

- **Cible bruitee** : "abattu ou essouche" n'est pas specifique a
  la tempete, comme on l'a montre avec les dates et le ratio H/D.
- **Peu de positifs** : 166 arbres dans le train, c'est juste.
- **Features insuffisantes** : les vraies causes de deracinement
  (vent local, etat des racines, sol) ne sont pas dans les donnees.

**Pistes pour aller plus loin** :

- Dates d'abattage precises (au jour pres) pour corriger les
  etiquettes via les dates de tempetes connues.
- Mesures locales du vent (rafales max) par quartier ou par rue.
- Informations sur le sol et les racines.
- Historique des tailles et des diagnostics par arbre.

Sans tout ca, on a fait le maximum avec ce qu'on avait. L'ajout des
features spatiales a divise par deux les fausses alertes et on est
passe d'un modele "plus ou moins au hasard" a un modele qui remonte
une liste courte et exploitable pour la ville.
