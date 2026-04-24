"""
Script final du besoin client 2 : prédiction de l'âge d'un arbre.

Le script charge trois modèles déja entrainé et sort l'âge de l'arbre.

Usage :
  python predict.py --haut_tot 7 --haut_tronc 2  \
      --tronc_diam 48 --fk_stadedev jeune
"""

import joblib
import numpy as np
import pandas as pd
import argparse
from pathlib import Path

# Dictionnaire des modèles
models = {
    1: ("Linear Regression", Path(__file__).resolve().parent / "linear_regression.pkl"),
    2: ("Decision Tree", Path(__file__).resolve().parent / "decision_tree.pkl"),
    3: ("Random Forest", Path(__file__).resolve().parent / "random_forest.pkl")
}

# Charger le scaler (version 1.6.1)
chemin_scaler = Path(__file__).resolve().parent / "scaler.pkl"
scaler = joblib.load(chemin_scaler)

# Charger l'encoder
chemin_encoder = Path(__file__).resolve().parent / "encoder.pkl"
encoder = joblib.load(chemin_encoder)

stades = {
    "adulte": 0.0,
    "jeune": 1.0,
    "senescent": 2.0,
    "vieux": 3.0,
}

def parser_arguments():
    p = argparse.ArgumentParser(description="Prediction de l'âge d'un arbre")

    # Variables numeriques obligatoires
    p.add_argument("--haut_tot", type=float, required=True,
                   help="Hauteur totale en metres")
    p.add_argument("--haut_tronc", type=float, required=True,
                   help="Hauteur du tronc en metres")
    p.add_argument("--tronc_diam", type=float, required=True,
                   help="Diametre du tronc en cm")

    # Variable categorielles obligatoires
    p.add_argument("--fk_stadedev", default="inconnu", required=True,
                    help="Stade de développement de l'arbre : adulte, jeune, senescent ou vieux")

    return p.parse_args()

def load_model(choice):
    name, path = models[choice]
    model = joblib.load(path)
    return name, model

def predict_age(model, features):
    features_scaled = scaler.transform(features)
    return model.predict(features_scaled)[0]

def main():
    args = parser_arguments()

    stade = stades.get(args.fk_stadedev)
    hauteur_total = args.haut_tot
    hauteur = args.haut_tronc
    diametre = args.tronc_diam

    # Construire le vecteur
    columns = ["haut_tot", "haut_tronc", "tronc_diam", "fk_stadedev"]
    features = pd.DataFrame([[hauteur_total, hauteur, diametre, stade]], columns=columns)

    for choice_model in models:
        model_name, model = load_model(choice_model)
        age = predict_age(model, features)
        print(f"Âge prédit par {model_name} : {age:.2f}")

if __name__ == "__main__":
    main()