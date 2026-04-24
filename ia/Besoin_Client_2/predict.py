"""
Script final du besoin client 2 : prédiction de l'âge d'un arbre.

Le script charge trois modèles déja entrainé et sort l'âge de l'arbre.

Usage :
  python predict.py --haut_tot 7 --haut_tronc 2  \
      --tronc_diam 48 --fk_stadedev jeune
"""

# Bibliothèques utilisé
import joblib
import numpy as np
import pandas as pd
import argparse
from pathlib import Path

# Dictionnaire des modèles
models = {
    1: ("Linear Regression", Path(__file__).resolve().parent / "Models/linear_regression.pkl"),
    2: ("Decision Tree", Path(__file__).resolve().parent / "Models/decision_tree.pkl"),
    3: ("Random Forest", Path(__file__).resolve().parent / "Models/random_forest.pkl")
}

# Charger le scaler (version 1.6.1)
chemin_scaler = Path(__file__).resolve().parent / "Models/scaler.pkl"
scaler = joblib.load(chemin_scaler)

# Charger l'encoder
chemin_encoder = Path(__file__).resolve().parent / "Models/encoder.pkl"
encoder = joblib.load(chemin_encoder)

def parser_arguments():
    """
    Fonction pour passer les paramètres en ligne de commande

    return:
    Les arguments
    """
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
    """
    Fonction pour charger un modèle

    Args:
    choice (int) : Numéro du modèle choisi

    return:
    name (str) : Nom du modèle
    model : L'objet du modèle
    """
    name, path = models[choice]
    model = joblib.load(path)
    return name, model

def predict_age(model, features):
    """
    Fonction pour prédire l'âge de l'arbre sur un modèle (Met les données en scaler)

    args:
    model : L'objet du modèle
    features : Les paramètres pour prédire l'âge

    return:
    La prédiction du modèle
    """
    features_scaled = scaler.transform(features)
    return model.predict(features_scaled)[0]

def main():
    # Récupération des arguments
    args = parser_arguments()
    
    # Mise sous des variables
    hauteur_total = args.haut_tot
    hauteur = args.haut_tronc
    diametre = args.tronc_diam
    stadedev = args.fk_stadedev.lower()

    # Construire le vecteur
    columns_encoder = ["fk_stadedev"]
    stade = pd.DataFrame([[
        stadedev]], columns=columns_encoder)
    stade_encoding = encoder.transform(stade)
    columns = ["haut_tot", "haut_tronc", "tronc_diam", "fk_stadedev"]
    features = pd.DataFrame([[hauteur_total, hauteur, diametre, stade_encoding[0][0]]], columns=columns)

    # Exécution de la prédiction sur tout les modèles
    for choice_model in models:
        model_name, model = load_model(choice_model)
        age = predict_age(model, features)
        print(f"Âge prédit par {model_name} : {age:.2f}")

if __name__ == "__main__":
    main()