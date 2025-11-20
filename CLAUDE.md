# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

NHL Team Elo Rating System - Calcule des ratings Elo pour les équipes de la LNH afin de mesurer leur force relative et prédire les résultats des matchs.

**Objectif principal**: Optimiser le K-factor du système Elo pour maximiser la précision des prédictions sur 5 saisons (2020-21 à 2024-25).

**Stack technique**:
- Python pour le pipeline de données et calculs Elo
- R pour analyses statistiques avancées (optionnel)
- API NHL officielle (`https://api-web.nhle.com/`) comme source de données
- Possibilité future d'un dashboard web

## Common Commands

### Setup
```bash
python -m venv venv
source venv/bin/activate  # ou `venv\Scripts\activate` sur Windows
pip install -r requirements.txt
```

### Data Pipeline
```bash
# Récupérer les données NHL (5 dernières saisons)
python scripts/fetch_nhl_data.py --seasons 5

# Récupérer une saison spécifique
python scripts/fetch_nhl_data.py --season 20232024
```

### Elo Calculations
```bash
# Calculer les ratings Elo avec K-factor par défaut
python scripts/calculate_elo.py

# Calculer avec un K-factor spécifique
python scripts/calculate_elo.py --k-factor 20

# Optimiser le K-factor par validation croisée
python scripts/optimize_k_factor.py
```

### Predictions
```bash
# Générer des prédictions pour les matchs à venir
python scripts/predict_matches.py

# Évaluer la précision des prédictions historiques
python scripts/evaluate_predictions.py
```

### Testing
```bash
# Lancer tous les tests
pytest

# Tests avec couverture
pytest --cov=src tests/

# Tester un module spécifique
pytest tests/test_elo.py
```

### Code Quality
```bash
# Formater le code
black src/ tests/ scripts/

# Linting
flake8 src/ tests/ scripts/

# Type checking
mypy src/
```

## Architecture

### Data Flow
1. **Data Fetching** (`src/data/`) - Récupère les données de l'API NHL
   - `nhl_api.py`: Client pour l'API NHL officielle
   - `data_loader.py`: Charge et parse les données des matchs
   - `preprocessing.py`: Nettoie et transforme les données brutes

2. **Elo Engine** (`src/elo/`) - Calcule les ratings Elo
   - `elo_calculator.py`: Implémente le système Elo de base
   - `k_factor_optimizer.py`: Optimise le K-factor par grid search ou Bayesian optimization
   - `rating_history.py`: Maintient l'historique des ratings dans le temps

3. **Predictions** (`src/predictions/`) - Génère et évalue les prédictions
   - `predictor.py`: Utilise les ratings Elo pour prédire les matchs
   - `evaluator.py`: Calcule les métriques de performance (accuracy, log-loss, Brier score)
   - `backtesting.py`: Valide le système sur données historiques

4. **Utils** (`src/utils/`) - Fonctions utilitaires
   - `config.py`: Configuration centralisée
   - `logger.py`: Logging unifié
   - `helpers.py`: Fonctions communes

### Key Design Decisions

**Elo Rating Formula**:
```
Expected Score: E_A = 1 / (1 + 10^((R_B - R_A) / 400))
New Rating: R_A' = R_A + K * (S_A - E_A)
```
où S_A = 1 pour victoire, 0 pour défaite

**K-Factor Optimization**:
- Objectif: Minimiser le Brier score ou log-loss sur validation set
- Méthode: Grid search ou Bayesian optimization
- Range typique: K ∈ [10, 50]
- Validation: Time-series cross-validation (pas de look-ahead bias)

**Initial Ratings**:
- Option 1: Tous les teams démarrent à 1500
- Option 2: Régression vers la moyenne entre saisons (ex: R_new = 0.75 * R_old + 0.25 * 1500)

### Data Storage

**Raw Data** (`data/raw/`):
- Format: JSON (réponses API brutes)
- Organisation par saison: `games_20232024.json`

**Processed Data** (`data/processed/`):
- Format: Parquet (plus efficace que CSV)
- `matches.parquet`: Un match par ligne avec home/away teams, score, date
- `ratings_history.parquet`: Évolution des ratings dans le temps
- `predictions.parquet`: Prédictions et résultats réels

### NHL API Endpoints

Endpoints principaux utilisés:
- Schedule: `https://api-web.nhle.com/v1/schedule/{date}`
- Game details: `https://api-web.nhle.com/v1/gamecenter/{gameId}/boxscore`
- Standings: `https://api-web.nhle.com/v1/standings/{date}`

**Important**: L'API NHL officielle ne nécessite pas de clé API mais implémentez un rate limiting pour éviter les blocages.

### Time-Series Considerations

**Critical**: Les matchs doivent être traités en ordre chronologique strict pour:
1. Éviter le look-ahead bias
2. Refléter l'évolution réelle des ratings
3. Valider correctement les prédictions

**Validation strategy**:
- Walk-forward validation: entraîner sur saisons N-1, N-2, ... puis tester sur saison N
- Jamais utiliser de données futures pour calculer des ratings passés

## Notes importantes

- **Performance**: Utilisez pandas vectorization plutôt que des boucles pour calculer les ratings
- **Reproducibilité**: Fixez le random seed pour les optimisations stochastiques
- **Données manquantes**: L'API NHL peut avoir des données incomplètes pour certaines saisons COVID (2020-21)
- **Types de matchs**: Considérez si vous voulez traiter différemment regular season vs playoffs (actuellement non implémenté)

## Future Enhancements

Extensions possibles du système (non implémentées actuellement):
- Home ice advantage adjustment
- Margin of victory weighting
- Different K-factors pour regular season vs playoffs
- Decay factor pour réduire l'impact des matchs anciens
- Dashboard Streamlit/Dash pour visualisation interactive
