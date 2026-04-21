library(tidyverse)
df <- read_csv("data/clean/arbres_clean.csv", show_col_types = FALSE)

# combien de NA par variable cle
vars <- c("haut_tot","haut_tronc","tronc_diam","age_estim",
          "fk_stadedev","feuillage","clc_quartier")
cat("NA restants :\n")
print(sapply(df[vars], function(x) sum(is.na(x))))

# est-ce que la mediane par groupe a du sens ?
# on regarde la variance intra-groupe vs totale (ratio R2 type)
r2_groupe <- function(y, g) {
  d <- tibble(y, g) %>% drop_na()
  if (nrow(d) < 10) return(NA)
  tot <- var(d$y)
  wit <- d %>% group_by(g) %>% summarise(v = var(y), n = n()) %>%
    summarise(w = sum((n-1)*v, na.rm = TRUE) / (sum(n)-1)) %>% pull(w)
  round(1 - wit/tot, 3)
}

cat("\nR2 (part de variance expliquee par le groupe) :\n")
for (y in c("haut_tot","haut_tronc","tronc_diam","age_estim")) {
  for (g in c("fk_stadedev","nomlatin","clc_quartier","feuillage")) {
    cat(sprintf("  %-12s ~ %-14s  R2 = %s\n", y, g, r2_groupe(df[[y]], df[[g]])))
  }
}
