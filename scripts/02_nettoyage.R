library(tidyverse)
library(lubridate)
library(stringi)

df <- read_csv("data/raw/Data_Arbre.csv", show_col_types = FALSE)

# petit helper : normaliser les modalites (minuscules, sans accent, trim)
norm <- function(x) {
  x <- str_squish(x)
  x <- ifelse(x %in% c("", "RAS", "ras"), NA, x)
  stri_trans_general(tolower(x), "Latin-ASCII")
}

cat_vars <- c("fk_arb_etat","fk_stadedev","fk_port","fk_pied",
              "fk_situation","fk_revetement","feuillage","remarquable",
              "clc_quartier","clc_secteur","villeca","nomfrancais","nomlatin")

df <- df %>% mutate(across(all_of(cat_vars), norm))

# RAS -> NA dans les commentaires / noms tech aussi
df$commentaire_environnement <- ifelse(df$commentaire_environnement %in% c("RAS","ras","") |
                                         is.na(df$commentaire_environnement),
                                       NA, df$commentaire_environnement)
df$fk_nomtech <- norm(df$fk_nomtech)

# les 0 sur hauteurs / diametre / age : ca n'a pas de sens -> NA
df <- df %>% mutate(
  haut_tot    = ifelse(haut_tot == 0, NA, haut_tot),
  haut_tronc  = ifelse(haut_tronc == 0, NA, haut_tronc),
  tronc_diam  = ifelse(tronc_diam == 0, NA, tronc_diam),
  age_estim   = ifelse(age_estim == 0, NA, age_estim)
)

# aberrations
df$age_estim[df$age_estim > 200]         <- NA   # des gens ont saisi 2010 au lieu de l'age
df$tronc_diam[df$tronc_diam > 400]       <- NA   # > 4m ce n'est plus credible
df$haut_tronc[df$haut_tronc > df$haut_tot] <- NA

# dates : 1970-01-01 = valeur par defaut bidon
dp <- suppressWarnings(ymd_hms(df$dte_plantation, truncated = 3))
da <- suppressWarnings(ymd_hms(df$dte_abattage,   truncated = 3))
dp[year(dp) <= 1970] <- NA
df$dte_plantation <- as_date(dp)
df$dte_abattage   <- as_date(da)

# lignes sans coordonnees -> inutilisables
df <- df %>% filter(!is.na(X), !is.na(Y))

# doublons d'ID (il n'y en avait pas mais on securise)
df <- df %>% distinct(OBJECTID, .keep_all = TRUE)

# annee de reference = max observee dans les donnees (plantation ou abattage)
an_ref <- max(c(year(df$dte_plantation), year(df$dte_abattage)), na.rm = TRUE)
df$age_calc <- an_ref - year(df$dte_plantation)

# petit recap
cat("lignes :", nrow(df), "\n")
cat("annee ref :", an_ref, "\n")
cat("NA par colonne (top 10):\n")
print(sort(sapply(df, function(x) sum(is.na(x))), decreasing = TRUE)[1:10])

dir.create("data/clean", showWarnings = FALSE, recursive = TRUE)
write_csv(df, "data/clean/arbres_clean.csv")
