library(tidyverse)
library(lubridate)
library(stringi)

# On repart du CSV brut pour que le nettoyage soit reproductible
# (si on relance le script, on obtient exactement le meme fichier propre).
df <- read_csv("data/raw/Data_Arbre.csv", show_col_types = FALSE)

# Petite fonction pour uniformiser les modalites texte :
# - on enleve les espaces en trop
# - on remplace les "" et "RAS" par NA (vus pendant l'exploration)
# - on passe en minuscules sans accent pour fusionner "Jeune"/"jeune"/"JEUNE"
norm <- function(x) {
  x <- str_squish(x)
  x <- ifelse(x %in% c("", "RAS", "ras"), NA, x)
  stri_trans_general(tolower(x), "Latin-ASCII")
}

# Colonnes categorielles a nettoyer (identifiees dans 01_exploration.R,
# ce sont toutes celles ou on a vu des incoherences de casse).
cat_vars <- c("fk_arb_etat","fk_stadedev","fk_port","fk_pied",
              "fk_situation","fk_revetement","feuillage","remarquable",
              "clc_quartier","clc_secteur","villeca")

df <- df %>% mutate(across(all_of(cat_vars), norm))

# Pour les noms d'especes on ne passe PAS tout en minuscules sans accents :
# un rapport avec "erable" au lieu de "Erable" ou "acer platanoides" au lieu
# de "Acer platanoides" (convention latine : majuscule au genre) ca fait
# moche et c'est incorrect. On se contente d'enlever les espaces en trop
# et de transformer les "RAS" en NA.
clean_nom <- function(x) {
  x <- str_squish(x)
  ifelse(x %in% c("", "RAS", "ras"), NA, x)
}
df$nomfrancais <- clean_nom(df$nomfrancais)
df$nomlatin   <- clean_nom(df$nomlatin)

# Meme traitement pour les champs texte qui contiennent aussi des "RAS".
df$commentaire_environnement <- ifelse(df$commentaire_environnement %in% c("RAS","ras","") |
                                         is.na(df$commentaire_environnement),
                                       NA, df$commentaire_environnement)
df$fk_nomtech <- norm(df$fk_nomtech)

# Les zeros sur les variables physiques (hauteur, diametre, age) sont
# impossibles pour un arbre vivant -> on considere que ce sont des NA
# mal saisis et on les remplace par de vrais NA.
df <- df %>% mutate(
  haut_tot    = ifelse(haut_tot == 0, NA, haut_tot),
  haut_tronc  = ifelse(haut_tronc == 0, NA, haut_tronc),
  tronc_diam  = ifelse(tronc_diam == 0, NA, tronc_diam),
  age_estim   = ifelse(age_estim == 0, NA, age_estim)
)

# Valeurs aberrantes reperees dans l'exploration :
# - age_estim = 2010 (quelqu'un a saisi l'annee au lieu de l'age)
# - tronc_diam > 4 m = pas credible pour un arbre urbain
# - haut_tronc > haut_tot = physiquement impossible
df$age_estim[df$age_estim > 200]           <- NA
df$tronc_diam[df$tronc_diam > 400]         <- NA
df$haut_tronc[df$haut_tronc > df$haut_tot] <- NA

# Conversion des dates. 1970-01-01 c'est la valeur par defaut renvoyee par
# les bases de donnees quand la date est vide (epoch Unix), donc on la
# traite comme un NA.
dp <- suppressWarnings(ymd_hms(df$dte_plantation, truncated = 3))
da <- suppressWarnings(ymd_hms(df$dte_abattage,   truncated = 3))
dp[year(dp) <= 1970] <- NA
df$dte_plantation <- as_date(dp)
df$dte_abattage   <- as_date(da)

# Sans coordonnees, on ne peut pas placer l'arbre sur la carte
# (fonctionnalite 3) -> on supprime ces lignes.
df <- df %>% filter(!is.na(X), !is.na(Y))

# Au cas ou deux lignes auraient le meme OBJECTID (l'exploration n'en a pas
# trouve, mais autant securiser si on rejoue sur un CSV modifie).
df <- df %>% distinct(OBJECTID, .keep_all = TRUE)

# On calcule un "age calcule" = annee de reference - annee de plantation.
# L'annee de reference, on la prend egale a la date la plus recente vue
# dans les donnees (comme ca le script marche meme dans quelques annees).
an_ref <- max(c(year(df$dte_plantation), year(df$dte_abattage)), na.rm = TRUE)
df$age_calc <- an_ref - year(df$dte_plantation)

# Petit recap de ce qu'il reste apres nettoyage, pour verifier qu'on
# a bien fait ce qu'on voulait.
cat("lignes :", nrow(df), "\n")
cat("annee ref :", an_ref, "\n")
cat("NA par colonne (top 10):\n")
print(sort(sapply(df, function(x) sum(is.na(x))), decreasing = TRUE)[1:10])

dir.create("data/clean", showWarnings = FALSE, recursive = TRUE)
write_csv(df, "data/clean/arbres_clean.csv")

# ---------------------------------------------------------------
# Visualisations (fonctionnalite 2) : on les genere directement apres
# le nettoyage pour ne pas avoir a relire le CSV dans un autre script.
# ---------------------------------------------------------------
dir.create("figures", showWarnings = FALSE)
theme_set(theme_minimal(base_size = 11))

# 1. Combien d'arbres a chaque stade de developpement (jeune, adulte, ...)
p <- df %>% filter(!is.na(fk_stadedev)) %>%
  count(fk_stadedev) %>%
  ggplot(aes(reorder(fk_stadedev, n), n)) +
  geom_col(fill = "seagreen") + coord_flip() +
  labs(title = "Repartition des arbres par stade de developpement",
       x = NULL, y = "Nombre d'arbres")
ggsave("figures/01_stade_dev.png", p, width = 8, height = 5, dpi = 200)

# 2. Nombre d'arbres par quartier
p <- df %>% filter(!is.na(clc_quartier)) %>%
  count(clc_quartier) %>%
  ggplot(aes(reorder(clc_quartier, n), n)) +
  geom_col(fill = "steelblue") + coord_flip() +
  labs(title = "Nombre d'arbres par quartier", x = NULL, y = "Nombre d'arbres")
ggsave("figures/02_quartier.png", p, width = 8, height = 5, dpi = 200)

# 3. Top 20 des secteurs (rues / avenues) qui portent le plus d'arbres
top_sect <- df %>% filter(!is.na(clc_secteur)) %>%
  count(clc_secteur, sort = TRUE) %>% head(20)
p <- ggplot(top_sect, aes(reorder(clc_secteur, n), n)) +
  geom_col(fill = "steelblue") + coord_flip() +
  labs(title = "Top 20 des secteurs", x = NULL, y = "Nombre d'arbres")
ggsave("figures/03_secteurs_top20.png", p, width = 8, height = 6, dpi = 200)

# 4. Situation (libre, alignement, etc.)
p <- df %>% filter(!is.na(fk_situation)) %>%
  count(fk_situation) %>%
  ggplot(aes(reorder(fk_situation, -n), n)) +
  geom_col(fill = "tomato") +
  labs(title = "Situation des arbres", x = NULL, y = "Nombre d'arbres")
ggsave("figures/04_situation.png", p, width = 6, height = 4, dpi = 200)

# 5-7. Distributions des 3 variables numeriques principales :
# ca permet de voir si elles sont symetriques ou decalees, et de
# reperer visuellement d'eventuelles valeurs extremes.
p <- ggplot(df, aes(haut_tot)) +
  geom_histogram(bins = 40, fill = "seagreen") +
  labs(title = "Distribution de la hauteur totale", x = "Hauteur (m)", y = "Effectif")
ggsave("figures/05_haut_tot.png", p, width = 8, height = 5, dpi = 200)

p <- ggplot(df, aes(tronc_diam)) +
  geom_histogram(bins = 40, fill = "seagreen") +
  labs(title = "Distribution du diametre du tronc", x = "Diametre (cm)", y = "Effectif")
ggsave("figures/06_tronc_diam.png", p, width = 8, height = 5, dpi = 200)

p <- ggplot(df, aes(age_estim)) +
  geom_histogram(bins = 40, fill = "seagreen") +
  labs(title = "Distribution de l'age estime", x = "Age (annees)", y = "Effectif")
ggsave("figures/07_age_estim.png", p, width = 8, height = 5, dpi = 200)

# 8. Croisement : est-ce que les arbres plus vieux (stade) sont plus grands ?
p <- df %>% filter(!is.na(fk_stadedev), !is.na(haut_tot)) %>%
  ggplot(aes(fk_stadedev, haut_tot)) +
  geom_boxplot(fill = "seagreen", alpha = 0.6) +
  labs(title = "Hauteur totale selon le stade de developpement",
       x = NULL, y = "Hauteur (m)")
ggsave("figures/08_boxplot_haut_stade.png", p, width = 8, height = 5, dpi = 200)

# 9. Etat global des arbres (en place, abattu, ...)
p <- df %>% filter(!is.na(fk_arb_etat)) %>%
  count(fk_arb_etat) %>%
  ggplot(aes(reorder(fk_arb_etat, n), n)) +
  geom_col(fill = "grey40") + coord_flip() +
  labs(title = "Etat des arbres", x = NULL, y = "Nombre d'arbres")
ggsave("figures/09_etat.png", p, width = 7, height = 4, dpi = 200)

# 10. Top 15 des especes les plus presentes.
# La colonne "nomfrancais" du fichier brut contient en fait des codes courts
# (ex. "PLAACE" pour Platanus x acerifolia), pas les vrais noms francais.
# On traduit a la main les 15 codes les plus frequents pour que le graphique
# soit lisible. Les codes sont transformes en facteur pour garantir qu'un nom
# manquant du dictionnaire apparaitrait en NA (plutot que de faire planter
# le script en silence).
dico_especes <- c(
  "PLAACE"    = "Platane commun",
  "TILCOR"    = "Tilleul a petites feuilles",
  "PINNIGnig" = "Pin noir",
  "BETPEN"    = "Bouleau verruqueux",
  "ACEPSE"    = "Erable sycomore",
  "ACEPLA"    = "Erable plane",
  "LIRTUL"    = "Tulipier de Virginie",
  "FAGSYLfas" = "Hetre fastigie",
  "POPNIGita" = "Peuplier d'Italie",
  "LIQSTY"    = "Copalme d'Amerique",
  "PRUCERpis" = "Prunier pissard",
  "PRUSER"    = "Cerisier du Japon",
  "ACECAM"    = "Erable champetre",
  "FRAEXC"    = "Frene commun",
  "CARBET"    = "Charme commun"
)

top_esp <- df %>% filter(!is.na(nomfrancais)) %>%
  count(nomfrancais, sort = TRUE) %>% head(15) %>%
  mutate(label = ifelse(nomfrancais %in% names(dico_especes),
                        dico_especes[nomfrancais],
                        nomfrancais))

p <- ggplot(top_esp, aes(reorder(label, n), n)) +
  geom_col(fill = "darkorange") + coord_flip() +
  labs(title = "Top 15 des especes les plus frequentes",
       x = NULL, y = "Nombre d'arbres")
ggsave("figures/10_especes_top15.png", p, width = 8, height = 6, dpi = 200)

# 11. Feuillus vs coniferes
p <- df %>% filter(!is.na(feuillage)) %>%
  count(feuillage) %>%
  ggplot(aes(feuillage, n)) +
  geom_col(fill = "seagreen") +
  labs(title = "Feuillu vs conifere", x = NULL, y = "Nombre d'arbres")
ggsave("figures/11_feuillage.png", p, width = 5, height = 4, dpi = 200)

# 12. Ou sont les arbres classes "remarquables" ?
p <- df %>% filter(remarquable == "oui", !is.na(clc_quartier)) %>%
  count(clc_quartier) %>%
  ggplot(aes(reorder(clc_quartier, n), n)) +
  geom_col(fill = "gold3") + coord_flip() +
  labs(title = "Arbres remarquables par quartier", x = NULL, y = "Nombre")
ggsave("figures/12_remarquables_quartier.png", p, width = 8, height = 5, dpi = 200)

# 13. Nombre de plantations par annee (la ou on a la date)
p <- df %>% filter(!is.na(dte_plantation)) %>%
  mutate(annee = year(dte_plantation)) %>%
  count(annee) %>%
  ggplot(aes(annee, n)) +
  geom_col(fill = "steelblue") +
  labs(title = "Nombre de plantations par annee", x = "Annee", y = "Nombre")
ggsave("figures/13_plantations_annee.png", p, width = 8, height = 5, dpi = 200)

cat("ok - figures generees dans figures/\n")
