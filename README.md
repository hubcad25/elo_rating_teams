# NHL Team Elo Rating System

Système de classement Elo pour mesurer la force relative des équipes de la LNH (NHL) et prédire les résultats des matchs.

## Objectif

Calculer des ratings Elo pour toutes les équipes NHL et optimiser le K-factor pour maximiser la précision des prédictions.

**Période d'analyse**: Depuis 2007-08 (17+ saisons)
**Approche**: Continue - les ratings persistent entre saisons sans reset

## Sources de données

- **API NHL officielle**: `https://api-web.nhle.com/` (intégration à venir)
- Actuellement: Données mockées réalistes pour développement et tests

## Structure du projet

```
elo_rating_teams/
├── src/
│   ├── elo_rating.R          # Système Elo complet (calculs, prédictions, évaluation)
│   ├── generate_mock_data.R  # Générateur de données fictives
│   ├── optimize_k_factor.R   # Optimisation du K-factor (grid/bayesian)
│   └── visualize_elo.R       # Graphiques et visualisations
├── scripts/
│   ├── run_elo_analysis.R        # Pipeline complet
│   ├── optimize_k.R              # Script d'optimisation standalone
│   └── create_visualizations.R   # Génération de graphiques
├── data/
│   ├── raw/           # Données brutes (mockées ou API)
│   └── processed/     # Ratings et historique (CSV)
└── plots/             # Visualisations générées (PNG)
```

## Installation

### Prérequis
- R (version 4.0+)
- Packages R: dplyr, lubridate, readr, ggplot2, scales, optparse, parallel

```bash
# Installer les dépendances R
R -e "install.packages(c('dplyr', 'lubridate', 'readr', 'ggplot2', 'scales', 'optparse', 'parallel'))"
```

## Utilisation

### 1. Analyse complète (Quick Start)
```bash
Rscript scripts/run_elo_analysis.R
```
Génère:
- Ratings Elo pour toutes les équipes
- Historique complet des ratings
- Métriques de performance (Brier score, accuracy, log-loss)
- Exemples de prédictions

### 2. Optimisation du K-factor
```bash
# Grid search
Rscript scripts/optimize_k.R --method grid --k-min 10 --k-max 50

# Plus rapide: Bayesian optimization
Rscript scripts/optimize_k.R --method bayesian
```

### 3. Visualisations
```bash
Rscript scripts/create_visualizations.R
```
Crée 5 graphiques dans `plots/`:
- Évolution temporelle des ratings
- Rankings finaux
- Calibration du modèle
- Distribution des erreurs
- Matrice des matchups

## Méthodologie Elo

### Formule de base
```
Probabilité de victoire: E_A = 1 / (1 + 10^((R_B - R_A) / 400))
Nouveau rating: R_A' = R_A + K * (Résultat - E_A)
```

### Caractéristiques
- **Approche continue**: Les ratings persistent entre saisons (pas de reset annuel)
- **K-factor optimisé**: Par validation croisée time-series sur ~17 saisons
- **Métriques**: Brier score, accuracy, log-loss
- **Validation**: Walk-forward pour éviter le look-ahead bias

### Prochaines améliorations possibles
- Ajustement pour avantage domicile (+50 points Elo?)
- K-factor dynamique basé sur continuité du roster
- Pondération margin of victory
- Différenciation saison régulière vs playoffs
- Dashboard web interactif (Shiny/Streamlit)
- Intégration API NHL réelle (Python)
