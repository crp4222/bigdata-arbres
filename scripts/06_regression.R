# ============================================================
# FONCTIONNALITE 5 - Utilisation des régressions
# ============================================================

# --- Chargement des données ---
arbres <- read.csv("data/clean/arbres_clean.csv",
                   sep = ",", header = TRUE,
                   stringsAsFactors = TRUE, encoding = "UTF-8")

# --- Analyse des zones (quartiers) ---
# Spacial : Zones avec le moins d'arbres = HARLY, NEUVILLE, ROUVROY
# Temporel : Zones avec des arbres vieux, sans trop de jeune = Quartier de l'Europe, Remicourt, Centre-Ville

# --- Partie Régression linéaire ---
# Chargement du modèle
modele_lm <- lm(age_estim~haut_tot + haut_tronc + tronc_diam, data=arbres)

# Analyse des composants et du R²
summary(modele_lm)

# --- Partie Régression logistique ---
# Mise en binaire des arbres abattu
arbres$a_abattre <- ifelse(arbres$fk_arb_etat %in% c("abattu"), 1, 0)

# Nettoyage des données NA
arbres <- arbres[!is.na(arbres$fk_arb_etat), ]
arbres <- arbres[!is.na(arbres$haut_tot), ]
arbres <- arbres[!is.na(arbres$tronc_diam), ]
arbres <- arbres[!is.na(arbres$age_estim), ]
arbres <- arbres[!is.na(arbres$fk_stadedev), ]
arbres <- arbres[!is.na(arbres$haut_tronc), ]

# Chargement du modèle logistique
modele_logit <- glm(a_abattre ~ haut_tot + haut_tronc + tronc_diam + age_estim +
                      fk_stadedev,
                    data = arbres,
                    family = binomial)

# Visualisation des composants
summary(modele_logit)

# Application de la prédiction sur le modèle
proba <- predict(modele_logit, type = "response")
arbres$prediction <- ifelse(proba > 0.5, 1, 0)

# Matrice de confusion
table(Predit = arbres$prediction, Reel = arbres$a_abattre)
