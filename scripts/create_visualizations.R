#!/usr/bin/env Rscript
# Génère toutes les visualisations du système Elo
# Usage: Rscript scripts/create_visualizations.R

source("src/elo_rating.R")
source("src/visualize_elo.R")

library(dplyr)
library(readr)

cat("=== Génération des visualisations Elo ===\n\n")

# Charger les résultats
if (!file.exists("data/processed/ratings_history.csv") ||
    !file.exists("data/processed/final_ratings.csv")) {
  cat("Erreur: Données de ratings non trouvées.\n")
  cat("Exécutez d'abord: Rscript scripts/run_elo_analysis.R\n")
  quit(status = 1)
}

cat("Chargement des données...\n")
ratings_history <- read_csv("data/processed/ratings_history.csv", show_col_types = FALSE)
final_ratings <- read_csv("data/processed/final_ratings.csv", show_col_types = FALSE)

elo_results <- list(
  ratings_history = ratings_history,
  final_ratings = final_ratings
)

cat(sprintf("  → %d matchs dans l'historique\n", nrow(ratings_history) / 2))
cat(sprintf("  → %d équipes\n\n", nrow(final_ratings)))

# Générer tous les graphiques
save_all_plots(elo_results, output_dir = "plots")

cat("\n=== Visualisations terminées! ===\n")
cat("Consultez le dossier 'plots/' pour voir les graphiques.\n")
