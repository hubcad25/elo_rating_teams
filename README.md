# NHL Team Elo Rating System

Système de classement Elo pour mesurer la force relative des équipes de la LNH (NHL) et prédire les résultats des matchs.

## Objectif

Calculer des ratings Elo pour toutes les équipes NHL en utilisant les données des 5 dernières saisons (2020-21 à 2024-25) et optimiser le K-factor pour maximiser la précision des prédictions.

## Sources de données

- **API NHL officielle**: `https://api-web.nhle.com/`
- Données des matchs, scores, équipes

## Structure du projet

```
elo_rating_teams/
├── src/
│   ├── data/          # Récupération et traitement des données NHL API
│   ├── elo/           # Calculs Elo et optimisation K-factor
│   ├── predictions/   # Système de prédictions
│   └── utils/         # Utilitaires communs
├── data/
│   ├── raw/           # Données brutes de l'API
│   └── processed/     # Données traitées
├── tests/             # Tests unitaires
├── notebooks/         # Analyses exploratoires (Jupyter/R)
└── scripts/           # Scripts d'exécution
```

## Installation

```bash
python -m venv venv
source venv/bin/activate  # Linux/Mac
pip install -r requirements.txt
```

## Utilisation

```bash
# Récupérer les données NHL
python scripts/fetch_nhl_data.py --seasons 5

# Calculer les ratings Elo
python scripts/calculate_elo.py

# Optimiser le K-factor
python scripts/optimize_k_factor.py

# Générer des prédictions
python scripts/predict_matches.py
```

## Méthodologie Elo

Le système Elo calcule un rating pour chaque équipe basé sur:
- Résultats des matchs (victoire/défaite)
- Force relative des adversaires
- K-factor optimisé par validation croisée

### Prochaines améliorations possibles
- Ajustement pour avantage domicile
- Pondération margin of victory
- Différenciation saison régulière vs playoffs
- Dashboard interactif
