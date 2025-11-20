#!/usr/bin/env Rscript
# Script pour optimiser le K-factor
# Usage: Rscript scripts/optimize_k.R [--method grid|bayesian]

library(optparse)

# Parser les arguments
option_list <- list(
  make_option(c("-m", "--method"), type = "character", default = "grid",
              help = "Méthode d'optimisation: 'grid' ou 'bayesian' [défaut: %default]"),
  make_option(c("-f", "--folds"), type = "integer", default = 5,
              help = "Nombre de folds pour CV [défaut: %default]"),
  make_option(c("--k-min"), type = "integer", default = 10,
              help = "K-factor minimum [défaut: %default]"),
  make_option(c("--k-max"), type = "integer", default = 50,
              help = "K-factor maximum [défaut: %default]"),
  make_option(c("--parallel"), action = "store_true", default = FALSE,
              help = "Utiliser traitement parallèle"),
  make_option(c("-d", "--data"), type = "character", default = "data/raw/mock_nhl_games.csv",
              help = "Chemin vers les données [défaut: %default]")
)

opt_parser <- OptionParser(option_list = option_list)
opt <- parse_args(opt_parser)

# Charger les fonctions
source("src/elo_rating.R")
source("src/optimize_k_factor.R")
source("src/generate_mock_data.R")

library(dplyr)
library(readr)

cat("=== Optimisation du K-factor ===\n\n")

# Charger les données
if (file.exists(opt$data)) {
  cat(sprintf("Chargement: %s\n", opt$data))
  matches <- read_csv(opt$data, show_col_types = FALSE)
} else {
  cat("Aucune donnée trouvée, génération de données mockées...\n")
  matches <- generate_realistic_mock_data("2007-08", "2024-25")
  dir.create("data/raw", recursive = TRUE, showWarnings = FALSE)
  write_csv(matches, opt$data)
}

cat(sprintf("Matchs: %d\n", nrow(matches)))
cat(sprintf("Méthode: %s\n", opt$method))
cat(sprintf("Range K: [%d, %d]\n\n", opt$`k-min`, opt$`k-max`))

# Optimiser
if (opt$method == "grid") {
  k_range <- seq(opt$`k-min`, opt$`k-max`, by = 2)
  results <- optimize_k_factor_grid(
    matches_df = matches,
    k_range = k_range,
    n_folds = opt$folds,
    parallel = opt$parallel
  )
} else if (opt$method == "bayesian") {
  results <- optimize_k_factor_bayesian(
    matches_df = matches,
    n_iterations = 20,
    k_min = opt$`k-min`,
    k_max = opt$`k-max`
  )
} else {
  stop("Méthode inconnue. Utilisez 'grid' ou 'bayesian'")
}

# Sauvegarder les résultats
dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)
output_file <- "data/processed/k_factor_optimization.csv"
write_csv(results$all_results, output_file)

cat(sprintf("\nRésultats sauvegardés: %s\n", output_file))
cat(sprintf("\nK-factor optimal à utiliser: %d\n", results$k_optimal))
