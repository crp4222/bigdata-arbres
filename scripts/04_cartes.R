
# ============================================================
# FONCTIONNALITE 3 - Visualisation des données sur une carte
# ============================================================

library(leaflet)
library(sf)

# --- Chargement des données ---
df <- read.csv("data/raw/Data_Arbre.csv",
               sep = ",", header = TRUE,
               stringsAsFactors = FALSE, encoding = "UTF-8")

# --- Suppression des lignes sans coordonnées ---
df_clean <- df[!is.na(df$X) & !is.na(df$Y), ]

# --- Conversion EPSG:3949 -> WGS84 ---
df_sf <- st_as_sf(df_clean, coords = c("X", "Y"), crs = 3949)
df_wgs84 <- st_transform(df_sf, crs = 4326)
df_clean$lon_wgs84 <- st_coordinates(df_wgs84)[, 1]
df_clean$lat_wgs84 <- st_coordinates(df_wgs84)[, 2]

# --- Vérification ---
head(df_clean$lat_wgs84)  # ~49.8
head(df_clean$lon_wgs84)  # ~3.3

# --- Carte 1 : Tous les arbres ---
df_carte <- df_clean[!is.na(df_clean$lat_wgs84) & !is.na(df_clean$lon_wgs84), ]
carte_tous <- leaflet(df_carte) %>%
  addTiles() %>%
  addCircleMarkers(
    lng = ~lon_wgs84,
    lat = ~lat_wgs84,
    radius = 3,
    color = "green",
    popup = ~paste("Quartier:", clc_quartier, "<br>Espèce:", nomfrancais)
  )
carte_tous

# --- Carte 2 : Arbres remarquables ---
df_remarquables <- df_carte[df_carte$remarquable == "Oui", ]
carte_remarquables <- leaflet(df_remarquables) %>%
  addTiles() %>%
  addCircleMarkers(
    lng = ~lon_wgs84,
    lat = ~lat_wgs84,
    radius = 5,
    color = "red",
    popup = ~paste("Quartier:", clc_quartier, "<br>Espèce:", nomfrancais)
  )
carte_remarquables

# --- Carte 3 : Densité d'arbres par quartier ---
arbres_par_quartier <- as.data.frame(table(df_carte$clc_quartier))
colnames(arbres_par_quartier) <- c("quartier", "nb_arbres")

coords_quartier <- aggregate(cbind(lon_wgs84, lat_wgs84) ~ clc_quartier,
                             data = df_carte, FUN = mean)
colnames(coords_quartier)[1] <- "quartier"

quartier_data <- merge(arbres_par_quartier, coords_quartier, by = "quartier")

carte_quartiers <- leaflet(quartier_data) %>%
  addTiles() %>%
  addCircleMarkers(
    lng = ~lon_wgs84,
    lat = ~lat_wgs84,
    radius = ~sqrt(nb_arbres) * 1.5,
    color = "blue",
    fillOpacity = 0.5,
    popup = ~paste("Quartier:", quartier, "<br>Nombre d'arbres:", nb_arbres)
  )
carte_quartiers
