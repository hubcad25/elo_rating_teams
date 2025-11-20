#!/usr/bin/env Rscript
# Script principal pour calculer les ratings Elo et générer des prédictions
# Usage: Rscript scripts/run_elo_analysis.R

# Charger les fonctions
source("src/elo_rating.R")
source("src/generate_mock_data.R")

library(dplyr)
library(readr)

cat("=== NHL Elo Rating System ===\n\n")

# ============================================================================
# 1. GÉNÉRATION/CHARGEMENT DES DONNÉES
# ============================================================================

cat("Étape 1: Chargement des données...\n")

# Option A: Générer des données mockées
cat("Génération de données fictives (réalistes)...\n")
matches <- generate_realistic_mock_data(
  start_season = "2007-08",
  end_season = "2024-25"
)

# Sauvegarder pour réutilisation
dir.create("data/raw", recursive = TRUE, showWarnings = FALSE)
save_mock_data(matches, "data/raw/mock_nhl_games.csv")

# Option B: Charger des vraies données (quand disponibles)
# matches <- read_csv("data/raw/nhl_games.csv")

cat(sprintf("  → %d matchs chargés\n", nrow(matches)))
cat(sprintf("  → De %s à %s\n", min(matches$date), max(matches$date)))
cat(sprintf("  → %d équipes\n\n", length(unique(c(matches$home_team, matches$away_team)))))

# ============================================================================
# 2. CALCUL DES RATINGS ELO
# ============================================================================

cat("Étape 2: Calcul des ratings Elo...\n")
cat(sprintf("  → K-factor: %d\n", DEFAULT_K_FACTOR))
cat("  → Approche: Continue (pas de reset entre saisons)\n")

start_time <- Sys.time()
elo_results <- calculate_elo_ratings(
  matches_df = matches,
  k_factor = DEFAULT_K_FACTOR,
  initial_rating = INITIAL_RATING,
  continuous = TRUE
)
elapsed <- difftime(Sys.time(), start_time, units = "secs")

cat(sprintf("  → Calculé en %.2f secondes\n\n", elapsed))

# ============================================================================
# 3. AFFICHAGE DES RATINGS FINAUX
# ============================================================================

cat("Étape 3: Ratings finaux (Top 10):\n")
cat("========================================\n")
top_teams <- elo_results$final_ratings %>%
  head(10)

for (i in 1:nrow(top_teams)) {
  cat(sprintf("%2d. %-30s %7.1f\n",
              i,
              top_teams$team[i],
              top_teams$rating[i]))
}
cat("\n")

cat("Bottom 5:\n")
cat("========================================\n")
bottom_teams <- elo_results$final_ratings %>%
  tail(5)

for (i in 1:nrow(bottom_teams)) {
  cat(sprintf("%2d. %-30s %7.1f\n",
              nrow(elo_results$final_ratings) - 5 + i,
              bottom_teams$team[i],
              bottom_teams$rating[i]))
}
cat("\n")

# ============================================================================
# 4. ÉVALUATION DES PRÉDICTIONS
# ============================================================================

cat("Étape 4: Évaluation des prédictions:\n")
cat("========================================\n")

metrics <- evaluate_predictions(elo_results$ratings_history)

cat(sprintf("Brier Score:  %.4f  (plus bas = meilleur, random = 0.25)\n", metrics$brier_score))
cat(sprintf("Accuracy:     %.2f%%  (%%de prédictions correctes)\n", metrics$accuracy * 100))
cat(sprintf("Log Loss:     %.4f  (plus bas = meilleur)\n", metrics$log_loss))
cat(sprintf("Matchs:       %d\n\n", metrics$n_matches))

# ============================================================================
# 5. EXEMPLES DE PRÉDICTIONS
# ============================================================================

cat("Étape 5: Exemples de prédictions pour matchs futurs:\n")
cat("========================================\n")

# Prendre quelques équipes populaires
example_matchups <- list(
  c("Toronto Maple Leafs", "Montreal Canadiens"),
  c("Tampa Bay Lightning", "Florida Panthers"),
  c("Edmonton Oilers", "Colorado Avalanche"),
  c("Boston Bruins", "New York Rangers")
)

for (matchup in example_matchups) {
  pred <- predict_match(matchup[1], matchup[2], elo_results$final_ratings)

  cat(sprintf("\n%s (%.0f) vs %s (%.0f)\n",
              pred$home_team, pred$rating_home,
              pred$away_team, pred$rating_away))
  cat(sprintf("  → Prob victoire %s: %.1f%%\n",
              pred$home_team, pred$home_win_prob * 100))
  cat(sprintf("  → Prob victoire %s: %.1f%%\n",
              pred$away_team, pred$away_win_prob * 100))
}

cat("\n")

# ============================================================================
# 6. SAUVEGARDE DES RÉSULTATS
# ============================================================================

cat("Étape 6: Sauvegarde des résultats...\n")

dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)

write_csv(elo_results$final_ratings, "data/processed/final_ratings.csv")
write_csv(elo_results$ratings_history, "data/processed/ratings_history.csv")

cat("  → data/processed/final_ratings.csv\n")
cat("  → data/processed/ratings_history.csv\n")

cat("\n=== Analyse terminée! ===\n")
