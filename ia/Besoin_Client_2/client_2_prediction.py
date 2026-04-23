import joblib
import numpy as np
import pandas as pd

# Charger le scaler (version 1.6.1)
scaler = joblib.load("scaler.pkl")

# Dictionnaire des modèles
models = {
    1: ("Linear Regression", "linear_regression.pkl"),
    2: ("Decision Tree", "decision_tree.pkl"),
    3: ("Random Forest", "random_forest.pkl")
}

# Charger l'encoder
encoder = joblib.load("encoder.pkl")

# Menu stade
stades = {
    "adulte": 0.0,
    "jeune": 1.0,
    "senescent": 2.0,
    "vieux": 3.0,
    "nan": 4.0,
}

def load_model(choice):
    name, path = models[choice]
    model = joblib.load(path)
    return name, model

def predict_age(model, features):
    features_scaled = scaler.transform(features)
    return model.predict(features_scaled)[0]


if __name__ == "__main__":
    
    # Menu
    print("Choisissez un modèle :")
    for key, (name, _) in models.items():
        print(f"{key} - {name}")
    
    choice = int(input("Votre choix : "))
    
    if choice not in models:
        print("Choix invalide")
        exit()
    
    model_name, model = load_model(choice)
    
    print(f"Modèle sélectionné : {model_name}")

    # Features numériques
    hauteur_total = float(input("Hauteur totale : "))
    hauteur = float(input("Hauteur du tronc : "))
    diametre = float(input("Diamètre du tronc : "))

    print("Stade de développement :")
    for k, v in stades.items():
        print(f"{k} - {v}")

    choice = str(input("Votre choix : "))
    stade = stades.get(choice)

    # Construire le vecteur
    columns = ["haut_tot", "haut_tronc", "tronc_diam", "fk_stadedev"]
    features = pd.DataFrame([[hauteur_total, hauteur, diametre, stade]], columns=columns)
    
    age = predict_age(model, features)
    
    print(f"Âge prédit : {age}")