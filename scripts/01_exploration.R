library(tidyverse)
library(janitor)
library(skimr)
library(lubridate)

df <- read_csv("data/raw/Data_Arbre.csv", show_col_types = FALSE,
               col_types = cols(.default = col_character()))

dir.create("reports", showWarnings = FALSE)
dir.create("figures", showWarnings = FALSE)
sink("reports/01_exploration.txt", split = TRUE)

cat("dim:", dim(df), "\n\n")
print(names(df))

# types reels si on laisse R deviner
df2 <- read_csv("data/raw/Data_Arbre.csv", show_col_types = FALSE)
cat("\ntypes:\n"); print(sapply(df2, class))

# NA, "RAS", "0" (on les compte separement parce que RAS = NA cache)
na_tab <- tibble(
  col   = names(df),
  na    = sapply(df, function(x) sum(is.na(x) | x == "")),
  ras   = sapply(df, function(x) sum(x == "RAS", na.rm = TRUE)),
  zero  = sapply(df, function(x) sum(x == "0",   na.rm = TRUE)),
  uniq  = sapply(df, n_distinct)
) %>% mutate(pct_na = round(100*na/nrow(df), 1))
cat("\nNA / RAS / 0 :\n"); print(na_tab, n = Inf)

# stats num
num <- c("haut_tot","haut_tronc","tronc_diam","age_estim","clc_nbr_diag")
for (v in num) {
  x <- as.numeric(df[[v]])
  cat(sprintf("%s min=%g med=%g moy=%.1f max=%g NA=%d\n",
              v, min(x,na.rm=T), median(x,na.rm=T), mean(x,na.rm=T),
              max(x,na.rm=T), sum(is.na(x))))
}

# freq categorielles
for (v in c("fk_arb_etat","fk_stadedev","fk_port","fk_pied","fk_situation",
            "fk_revetement","feuillage","remarquable","clc_quartier")) {
  cat("\n", v, "\n"); print(count(df, .data[[v]], sort = TRUE))
}

# doublons
cat("\ndup OBJECTID:", sum(duplicated(df$OBJECTID)),
    " dup GlobalID:", sum(duplicated(df$GlobalID)), "\n")
cle <- paste(df$X, df$Y, df$nomlatin)
cat("dup (X,Y,espece):", sum(duplicated(cle)), "\n")

# valeurs louches
h <- as.numeric(df$haut_tot); tr <- as.numeric(df$haut_tronc)
d <- as.numeric(df$tronc_diam); a <- as.numeric(df$age_estim)
cat("\nhaut_tot==0:", sum(h==0,na.rm=T),
    "  >50m:", sum(h>50,na.rm=T),
    "\nhaut_tronc>haut_tot:", sum(tr>h,na.rm=T),
    "\ntronc_diam==0:", sum(d==0,na.rm=T),
    "  >500cm:", sum(d>500,na.rm=T),
    "\nage_estim==0:", sum(a==0,na.rm=T),
    "  >300:", sum(a>300,na.rm=T), "\n")

dp <- suppressWarnings(ymd_hms(df$dte_plantation, truncated = 3))
da <- suppressWarnings(ymd_hms(df$dte_abattage,   truncated = 3))
cat("plantation:", format(min(dp,na.rm=T)), "->", format(max(dp,na.rm=T)),
    " NA=", sum(is.na(dp)), "\n")
cat("abattage  :", format(min(da,na.rm=T)), "->", format(max(da,na.rm=T)),
    " NA=", sum(is.na(da)), "\n")

# petits histos de diag (on les reprendra propres apres nettoyage)
ggsave("figures/diag_haut_tot.png",
       ggplot(tibble(h=h), aes(h)) + geom_histogram(bins=60) + theme_minimal(),
       width=7, height=4, dpi=120)
ggsave("figures/diag_tronc_diam.png",
       ggplot(tibble(d=d), aes(d)) + geom_histogram(bins=60) + theme_minimal(),
       width=7, height=4, dpi=120)

sink()
