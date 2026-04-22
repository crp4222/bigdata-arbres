library(tidyverse)
library(lubridate)

# On va lire le fichier deux fois, pour deux usages differents :
#
# 1) df : on force tout en texte (character). Comme ca R ne transforme rien,
#    on voit exactement ce qui est ecrit dans le CSV (les "RAS", les "0",
#    les majuscules, les espaces en trop...). C'est utile pour reperer les
#    valeurs bizarres qu'on devra nettoyer.
#
# 2) df2 : on laisse R deviner les types tout seul. Ca permet de verifier
#    que les colonnes qui devraient etre numeriques (hauteur, diametre, age)
#    sont bien lues comme des nombres. Si une colonne numerique ressort en
#    "character", c'est qu'il y a du texte parasite dedans (par ex. "RAS")
#    qui empeche R de la lire comme un nombre -> signal qu'il faudra nettoyer.

df <- read_csv("data/raw/Data_Arbre.csv", show_col_types = FALSE,
               col_types = cols(.default = col_character()))

cat("dim:", dim(df), "\n\n")
print(names(df))

df2 <- read_csv("data/raw/Data_Arbre.csv", show_col_types = FALSE)
cat("\ntypes devines par R :\n"); print(sapply(df2, class))

# On compte les NA "normaux" (vides / NA) mais aussi les "RAS" et les "0" :
# en regardant le fichier on a vu que "RAS" sert de NA cache dans plusieurs
# colonnes, et que des 0 apparaissent sur des variables ou 0 n'a pas de sens
# (un arbre vivant ne peut pas mesurer 0 m).
na_tab <- tibble(
  col   = names(df),
  na    = sapply(df, function(x) sum(is.na(x) | x == "")),
  ras   = sapply(df, function(x) sum(x == "RAS", na.rm = TRUE)),
  zero  = sapply(df, function(x) sum(x == "0",   na.rm = TRUE)),
  uniq  = sapply(df, n_distinct)
) %>% mutate(pct_na = round(100*na/nrow(df), 1))
cat("\nNA / RAS / 0 :\n"); print(na_tab, n = Inf)

# Petit resume des variables numeriques pour reperer les ordres de grandeur
# et les valeurs extremes (min, max) qui vont nous servir plus tard a
# detecter les aberrations.
num <- c("haut_tot","haut_tronc","tronc_diam","age_estim","clc_nbr_diag")
for (v in num) {
  x <- as.numeric(df[[v]])
  cat(sprintf("%s min=%g med=%g moy=%.1f max=%g NA=%d\n",
              v, min(x,na.rm=T), median(x,na.rm=T), mean(x,na.rm=T),
              max(x,na.rm=T), sum(is.na(x))))
}

# Pour les variables categorielles on veut voir toutes les modalites :
# c'est a ce moment qu'on se rend compte qu'on a "Jeune" et "jeune",
# "Libre" et "libre", etc. -> il faudra uniformiser au nettoyage.
for (v in c("fk_arb_etat","fk_stadedev","fk_port","fk_pied","fk_situation",
            "fk_revetement","feuillage","remarquable","clc_quartier")) {
  cat("\n", v, "\n"); print(count(df, .data[[v]], sort = TRUE))
}

# Est-ce qu'on a des doublons ? On teste d'abord sur les identifiants
# techniques (normalement uniques), puis sur (coordonnees, espece) pour
# reperer d'eventuels arbres saisis deux fois au meme endroit.
cat("\ndup OBJECTID:", sum(duplicated(df$OBJECTID)),
    " dup GlobalID:", sum(duplicated(df$GlobalID)), "\n")
cle <- paste(df$X, df$Y, df$nomlatin)
cat("dup (X,Y,espece):", sum(duplicated(cle)), "\n")

# On cherche les valeurs physiquement impossibles ou tres suspectes :
# - hauteur / diametre / age a 0 -> sans doute des NA mal codes
# - hauteur du tronc plus grande que la hauteur totale -> incoherent
# - diametre > 500 cm (5 m !) ou age > 300 ans -> erreur de saisie
h <- as.numeric(df$haut_tot); tr <- as.numeric(df$haut_tronc)
d <- as.numeric(df$tronc_diam); a <- as.numeric(df$age_estim)
cat("\nhaut_tot==0:", sum(h==0,na.rm=T),
    "  >50m:", sum(h>50,na.rm=T),
    "\nhaut_tronc>haut_tot:", sum(tr>h,na.rm=T),
    "\ntronc_diam==0:", sum(d==0,na.rm=T),
    "  >500cm:", sum(d>500,na.rm=T),
    "\nage_estim==0:", sum(a==0,na.rm=T),
    "  >300:", sum(a>300,na.rm=T), "\n")

# Les dates arrivent au format "texte avec heure" -> on les parse.
# On verifie aussi la plage : si on voit 1970-01-01, c'est la valeur par
# defaut des bases de donnees (epoch Unix), pas une vraie date.
dp <- suppressWarnings(ymd_hms(df$dte_plantation, truncated = 3))
da <- suppressWarnings(ymd_hms(df$dte_abattage,   truncated = 3))
cat("plantation:", format(min(dp,na.rm=T)), "->", format(max(dp,na.rm=T)),
    " NA=", sum(is.na(dp)), "\n")
cat("abattage  :", format(min(da,na.rm=T)), "->", format(max(da,na.rm=T)),
    " NA=", sum(is.na(da)), "\n")

# ---------------------------------------------------------------
# Verification post-nettoyage : est-ce qu'on aurait pu imputer les NA
# restants par la mediane d'un groupe (par ex. mediane de hauteur par espece) ?
# On lance ce bloc seulement si le fichier nettoye existe deja.
# ---------------------------------------------------------------
if (file.exists("data/clean/arbres_clean.csv")) {
  clean <- read_csv("data/clean/arbres_clean.csv", show_col_types = FALSE)

  cat("\nNA restants apres nettoyage :\n")
  for (v in c("haut_tot","haut_tronc","tronc_diam","age_estim",
              "fk_stadedev","feuillage","clc_quartier")) {
    cat(sprintf("  %-14s %d\n", v, sum(is.na(clean[[v]]))))
  }

  # Idee : si on groupe par exemple par espece, est-ce que la hauteur varie
  # beaucoup a l'interieur de chaque groupe ? Si non, ca veut dire que
  # connaitre l'espece donne deja une bonne idee de la hauteur, donc
  # imputer par la moyenne du groupe aurait du sens.
  # On fait le test pour chaque paire (variable a imputer, groupe) en
  # regardant le R2 d'un simple lm(variable ~ groupe).
  cat("\nR2 par groupe :\n")
  for (y in c("haut_tot","haut_tronc","tronc_diam","age_estim")) {
    for (g in c("fk_stadedev","nomlatin","clc_quartier","feuillage")) {
      dd <- clean[, c(y, g)]
      dd <- dd[complete.cases(dd), ]
      if (nrow(dd) < 10) next
      modele <- lm(dd[[y]] ~ dd[[g]])
      r2 <- summary(modele)$r.squared
      cat("  ", y, " ~ ", g, "  R2 =", round(r2, 3), "\n")
    }
  }
}
