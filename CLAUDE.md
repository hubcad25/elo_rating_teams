# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

NHL Team Elo Rating System - Calcule des ratings Elo pour les équipes de la LNH afin de mesurer leur force relative et prédire les résultats des matchs.

**Objectif principal**: Optimiser le K-factor du système Elo pour maximiser la précision des prédictions sur 5 saisons (2020-21 à 2024-25).

**Stack technique**:
- R pour calculs Elo, optimisation K-factor et visualisations (implémenté)
- Python pour le pipeline de données NHL API (à implémenter)
- API NHL officielle (`https://api-web.nhle.com/`) comme source de données
- Possibilité future d'un dashboard web

**Méthodologie Elo**:
- Approche **continue**: Les ratings persistent entre les saisons sans reset
- Pas de régression vers la moyenne entre saisons (peut être ajouté plus tard)
- Potentiel futur: Ajustement dynamique du K-factor basé sur la continuité du roster

## Common Commands

### Setup R
```bash
# Installer les packages R nécessaires
R -e "install.packages(c('dplyr', 'lubridate', 'readr', 'ggplot2', 'scales', 'optparse', 'parallel'))"
```

### Workflow principal (R)

**1. Générer et analyser les données:**
```bash
# Lance l'analyse complète avec données mockées
Rscript scripts/run_elo_analysis.R

# Sortie:
# - data/processed/final_ratings.csv (ratings finaux)
# - data/processed/ratings_history.csv (historique complet)
```

**2. Optimiser le K-factor:**
```bash
# Grid search (méthode par défaut)
Rscript scripts/optimize_k.R --method grid --k-min 10 --k-max 50

# Optimisation bayésienne (plus rapide)
Rscript scripts/optimize_k.R --method bayesian

# Avec parallélisation
Rscript scripts/optimize_k.R --method grid --parallel

# Sortie: data/processed/k_factor_optimization.csv
```

**3. Créer les visualisations:**
```bash
# Génère tous les graphiques
Rscript scripts/create_visualizations.R

# Sortie: plots/*.png
# - rating_evolution.png: Évolution des ratings Top 10
# - final_ratings.png: Barplot des ratings finaux
# - calibration.png: Calibration du modèle
# - prediction_errors.png: Distribution des erreurs
# - matchup_matrix.png: Matrice des probabilités de victoire
```

### Setup Python (futur)
```bash
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### Data Pipeline (à implémenter)
```bash
# Récupérer les données NHL réelles
python scripts/fetch_nhl_data.py --start-season 2007-08 --end-season 2024-25
```

## Architecture

### Modules R (implémentés)

**Core Elo System** (`src/elo_rating.R`):
- `calculate_elo_ratings()`: Calcule les ratings pour tous les matchs (approche continue)
- `expected_score()`: Probabilité de victoire attendue
- `update_rating()`: Mise à jour du rating après un match
- `predict_match()`: Prédiction pour un match futur
- `evaluate_predictions()`: Métriques (Brier score, accuracy, log-loss)

**Data Generation** (`src/generate_mock_data.R`):
- `generate_mock_nhl_data()`: Génère des données aléatoires simples
- `generate_realistic_mock_data()`: Génère des données avec équipes de forces variables (recommandé)
- `save_mock_data()`: Sauvegarde en CSV

**K-Factor Optimization** (`src/optimize_k_factor.R`):
- `time_series_cv()`: Validation croisée time-series (walk-forward)
- `optimize_k_factor_grid()`: Grid search du K optimal
- `optimize_k_factor_bayesian()`: Optimisation bayésienne (plus rapide)

**Visualizations** (`src/visualize_elo.R`):
- `plot_rating_evolution()`: Évolution temporelle des ratings
- `plot_final_ratings()`: Barplot des ratings finaux
- `plot_calibration()`: Calibration prédictions vs réalité
- `plot_prediction_errors()`: Distribution des erreurs
- `plot_matchup_matrix()`: Heatmap des probabilités entre équipes
- `save_all_plots()`: Génère tous les graphiques

### Scripts d'exécution
- `scripts/run_elo_analysis.R`: Pipeline complet (données → calcul → évaluation → sauvegarde)
- `scripts/optimize_k.R`: Optimisation standalone du K-factor
- `scripts/create_visualizations.R`: Génération de tous les graphiques

### Modules Python (à implémenter)
1. **Data Fetching** (`src/data/`) - Récupération NHL API
2. **Integration** - Convertir données Python → format pour R

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
