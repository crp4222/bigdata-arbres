library(tidyverse)
library(lubridate)

df <- read_csv("data/clean/arbres_clean.csv", show_col_types = FALSE)
dir.create("figures", showWarnings = FALSE)
theme_set(theme_minimal(base_size = 11))

save <- function(p, nom, w=8, h=5) {
  ggsave(file.path("figures", nom), p, width=w, height=h, dpi=200)
}

# 1. repartition par stade de developpement
save(
  df %>% filter(!is.na(fk_stadedev)) %>%
    count(fk_stadedev) %>%
    mutate(fk_stadedev = fct_reorder(fk_stadedev, n)) %>%
    ggplot(aes(fk_stadedev, n)) +
    geom_col(fill = "seagreen") +
    coord_flip() +
    labs(title = "Repartition des arbres par stade de developpement",
         x = NULL, y = "Nombre d'arbres"),
  "01_stade_dev.png")

# 2. quantite par quartier
save(
  df %>% filter(!is.na(clc_quartier)) %>%
    count(clc_quartier) %>%
    mutate(clc_quartier = fct_reorder(clc_quartier, n)) %>%
    ggplot(aes(clc_quartier, n)) +
    geom_col(fill = "steelblue") +
    coord_flip() +
    labs(title = "Nombre d'arbres par quartier", x = NULL, y = "Nombre d'arbres"),
  "02_quartier.png")

# 3. top 20 secteurs
save(
  df %>% filter(!is.na(clc_secteur)) %>%
    count(clc_secteur, sort = TRUE) %>% slice_head(n = 20) %>%
    mutate(clc_secteur = fct_reorder(clc_secteur, n)) %>%
    ggplot(aes(clc_secteur, n)) +
    geom_col(fill = "steelblue") +
    coord_flip() +
    labs(title = "Top 20 des secteurs", x = NULL, y = "Nombre d'arbres"),
  "03_secteurs_top20.png", h = 6)

# 4. situation
save(
  df %>% filter(!is.na(fk_situation)) %>%
    count(fk_situation) %>%
    ggplot(aes(reorder(fk_situation, -n), n)) +
    geom_col(fill = "tomato") +
    labs(title = "Situation des arbres", x = NULL, y = "Nombre d'arbres"),
  "04_situation.png", w=6, h=4)

# 5-7. distributions numeriques
save(
  ggplot(df, aes(haut_tot)) +
    geom_histogram(bins = 40, fill = "seagreen") +
    labs(title = "Distribution de la hauteur totale", x = "Hauteur (m)", y = "Effectif"),
  "05_haut_tot.png")

save(
  ggplot(df, aes(tronc_diam)) +
    geom_histogram(bins = 40, fill = "seagreen") +
    labs(title = "Distribution du diametre du tronc", x = "Diametre (cm)", y = "Effectif"),
  "06_tronc_diam.png")

save(
  ggplot(df, aes(age_estim)) +
    geom_histogram(bins = 40, fill = "seagreen") +
    labs(title = "Distribution de l'age estime", x = "Age (annees)", y = "Effectif"),
  "07_age_estim.png")

# 8. haut_tot par stade (bivarie)
save(
  df %>% filter(!is.na(fk_stadedev), !is.na(haut_tot)) %>%
    ggplot(aes(fk_stadedev, haut_tot)) +
    geom_boxplot(fill = "seagreen", alpha = 0.6) +
    labs(title = "Hauteur totale selon le stade de developpement",
         x = NULL, y = "Hauteur (m)"),
  "08_boxplot_haut_stade.png")

# 9. etat des arbres
save(
  df %>% filter(!is.na(fk_arb_etat)) %>%
    count(fk_arb_etat) %>%
    mutate(fk_arb_etat = fct_reorder(fk_arb_etat, n)) %>%
    ggplot(aes(fk_arb_etat, n)) +
    geom_col(fill = "grey40") +
    coord_flip() +
    labs(title = "Etat des arbres", x = NULL, y = "Nombre d'arbres"),
  "09_etat.png", w=7, h=4)

# 10. top 15 especes
save(
  df %>% filter(!is.na(nomfrancais)) %>%
    count(nomfrancais, sort = TRUE) %>% slice_head(n = 15) %>%
    mutate(nomfrancais = fct_reorder(nomfrancais, n)) %>%
    ggplot(aes(nomfrancais, n)) +
    geom_col(fill = "darkorange") +
    coord_flip() +
    labs(title = "Top 15 des especes (nom francais)", x = NULL, y = "Nombre d'arbres"),
  "10_especes_top15.png", h=6)

# 11. feuillage
save(
  df %>% filter(!is.na(feuillage)) %>%
    count(feuillage) %>%
    ggplot(aes(feuillage, n)) +
    geom_col(fill = "seagreen") +
    labs(title = "Feuillu vs conifere", x = NULL, y = "Nombre d'arbres"),
  "11_feuillage.png", w=5, h=4)

# 12. remarquables par quartier
save(
  df %>% filter(remarquable == "oui", !is.na(clc_quartier)) %>%
    count(clc_quartier) %>%
    mutate(clc_quartier = fct_reorder(clc_quartier, n)) %>%
    ggplot(aes(clc_quartier, n)) +
    geom_col(fill = "gold3") +
    coord_flip() +
    labs(title = "Arbres remarquables par quartier", x = NULL, y = "Nombre"),
  "12_remarquables_quartier.png")

# 13. plantations par annee
save(
  df %>% filter(!is.na(dte_plantation)) %>%
    mutate(annee = year(dte_plantation)) %>%
    count(annee) %>%
    ggplot(aes(annee, n)) +
    geom_col(fill = "steelblue") +
    labs(title = "Nombre de plantations par annee", x = "Annee", y = "Nombre"),
  "13_plantations_annee.png")

cat("ok - figures dans figures/\n")
