# FONCTIONNALITE 4 - Analyse des corrélations

library(corrplot)
library(ggplot2)

# Chargement des données
df <- read.csv("data/raw/Data_Arbre.csv",
               sep = ",", header = TRUE,
               stringsAsFactors = FALSE, encoding = "UTF-8")

# 4.1 - Corrélations entre variables numériques

vars_num <- df[, sapply(df, is.numeric)]
vars_num <- vars_num[, colSums(is.na(vars_num)) < nrow(vars_num)]
mat_cor <- cor(vars_num, use = "complete.obs")

corrplot(mat_cor,
         method = "circle",
         type = "upper",
         tl.cex = 0.9,
         tl.col = "black",
         addCoef.col = "black",
         number.cex = 0.75,
         col = colorRampPalette(c("#d73027", "white", "#1a9850"))(200),
         title = "Corrélations entre variables numériques",
         mar = c(0, 0, 3, 0))

# 4.2 - Tableaux croisés

tableau_etat_remarq    <- table(df$fk_arb_etat, df$remarquable)
tableau_quartier_remarq <- table(df$clc_quartier, df$remarquable)

# 4.3 - Tests Chi²

chi2_etat <- chisq.test(tableau_etat_remarq)
cat("p-value état vs remarquable :", chi2_etat$p.value, "\n")

chi2_quartier <- chisq.test(tableau_quartier_remarq)
cat("p-value quartier vs remarquable :", chi2_quartier$p.value, "\n")

# 4.4 - Barplot : Arbres remarquables par quartier

df_remarq <- as.data.frame(tableau_quartier_remarq)
colnames(df_remarq) <- c("quartier", "remarquable", "nb")

ggplot(df_remarq, aes(x = reorder(quartier, -nb), y = nb, fill = remarquable)) +
  geom_bar(stat = "identity", position = "dodge") +
  scale_fill_manual(values = c("Non" = "#74c476", "Oui" = "#e6550d")) +
  labs(title = "Arbres remarquables par quartier",
       x = "Quartier", y = "Nombre d'arbres", fill = "Remarquable") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 9))

# 4.5 - Barplot : Arbres remarquables par état sanitaire

df_etat <- as.data.frame(tableau_etat_remarq)
colnames(df_etat) <- c("etat", "remarquable", "nb")

ggplot(df_etat, aes(x = reorder(etat, -nb), y = nb, fill = remarquable)) +
  geom_bar(stat = "identity", position = "fill") +
  scale_fill_manual(values = c("Non" = "#74c476", "Oui" = "#e6550d")) +
  scale_y_continuous(labels = scales::percent) +
  labs(title = "Proportion d'arbres remarquables par état sanitaire",
       x = "État sanitaire", y = "Proportion", fill = "Remarquable") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 9))

# 4.6 - Boxplot : hauteur et diamètre selon état sanitaire

ggplot(df[!is.na(df$haut_tot) & df$haut_tot > 0, ],
       aes(x = fk_arb_etat, y = haut_tot, fill = fk_arb_etat)) +
  geom_boxplot(outlier.alpha = 0.3) +
  labs(title = "Hauteur des arbres selon l'état sanitaire",
       x = "État sanitaire", y = "Hauteur totale (m)") +
  theme_minimal() +
  theme(legend.position = "none",
        axis.text.x = element_text(angle = 45, hjust = 1))

ggplot(df[!is.na(df$tronc_diam) & df$tronc_diam > 0, ],
       aes(x = fk_arb_etat, y = tronc_diam, fill = fk_arb_etat)) +
  geom_boxplot(outlier.alpha = 0.3) +
  labs(title = "Diamètre du tronc selon l'état sanitaire",
       x = "État sanitaire", y = "Diamètre du tronc (cm)") +
  theme_minimal() +
  theme(legend.position = "none",
        axis.text.x = element_text(angle = 45, hjust = 1))

