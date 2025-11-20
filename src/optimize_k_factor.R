# Optimisation du K-factor par validation croisée
# Trouve le K-factor optimal qui minimise le Brier score

library(dplyr)
library(parallel)

source("src/elo_rating.R")

#' Effectue une validation croisée time-series
#'
#' @param matches_df DataFrame de tous les matchs
#' @param k_factor K-factor à tester
#' @param n_folds Nombre de folds (défaut = 5)
#' @return Brier score moyen sur tous les folds
time_series_cv <- function(matches_df, k_factor, n_folds = 5) {

  # Trier par date
  matches_df <- matches_df %>%
    arrange(date)

  n_matches <- nrow(matches_df)
  fold_size <- floor(n_matches / n_folds)

  brier_scores <- numeric(n_folds)

  # Walk-forward validation
  for (fold in 1:n_folds) {
    # Train sur les matchs 1 à fold*fold_size
    train_end <- fold * fold_size

    if (fold == n_folds) {
      # Dernier fold: utiliser tout ce qui reste
      test_indices <- (train_end - fold_size + 1):n_matches
    } else {
      test_indices <- (train_end - fold_size + 1):train_end
    }

    train_indices <- 1:(train_end - fold_size)

    if (length(train_indices) < 100) {
      # Pas assez de données d'entraînement, skip ce fold
      next
    }

    train_data <- matches_df[train_indices, ]
    test_data <- matches_df[test_indices, ]

    # Calculer Elo sur train
    elo_train <- calculate_elo_ratings(
      train_data,
      k_factor = k_factor,
      continuous = TRUE
    )

    # Obtenir les ratings finaux du train
    final_ratings <- elo_train$final_ratings

    # Évaluer sur test
    test_predictions <- data.frame()

    for (i in 1:nrow(test_data)) {
      match <- test_data[i, ]

      home_rating <- final_ratings %>%
        filter(team == match$home_team) %>%
        pull(rating)

      away_rating <- final_ratings %>%
        filter(team == match$away_team) %>%
        pull(rating)

      if (length(home_rating) == 0) home_rating <- INITIAL_RATING
      if (length(away_rating) == 0) away_rating <- INITIAL_RATING

      expected_home <- expected_score(home_rating, away_rating)
      actual_home <- ifelse(match$home_score > match$away_score, 1, 0)

      test_predictions <- rbind(test_predictions, data.frame(
        expected_win_prob = expected_home,
        actual_result = actual_home
      ))

      # Mettre à jour les ratings pour le prochain match du test set
      expected_away <- 1 - expected_home
      actual_away <- 1 - actual_home

      new_home <- update_rating(home_rating, expected_home, actual_home, k_factor)
      new_away <- update_rating(away_rating, expected_away, actual_away, k_factor)

      final_ratings$rating[final_ratings$team == match$home_team] <- new_home
      final_ratings$rating[final_ratings$team == match$away_team] <- new_away
    }

    brier_scores[fold] <- calculate_brier_score(test_predictions)
  }

  # Retourner le Brier score moyen
  mean(brier_scores[brier_scores > 0])
}

#' Optimise le K-factor par grid search
#'
#' @param matches_df DataFrame de matchs
#' @param k_range Vecteur de K-factors à tester (défaut = seq(10, 50, by = 2))
#' @param n_folds Nombre de folds pour CV
#' @param parallel Si TRUE, utilise traitement parallèle
#' @return Liste avec k_optimal et tous les résultats
optimize_k_factor_grid <- function(matches_df,
                                    k_range = seq(10, 50, by = 2),
                                    n_folds = 5,
                                    parallel = FALSE) {

  cat(sprintf("Optimisation du K-factor par grid search\n"))
  cat(sprintf("  → Range: %d à %d\n", min(k_range), max(k_range)))
  cat(sprintf("  → %d valeurs à tester\n", length(k_range)))
  cat(sprintf("  → %d-fold time-series CV\n\n", n_folds))

  if (parallel) {
    cat("Mode parallèle activé\n")
    n_cores <- detectCores() - 1
    cl <- makeCluster(n_cores)
    clusterExport(cl, c("calculate_elo_ratings", "expected_score", "update_rating",
                        "calculate_brier_score", "INITIAL_RATING",
                        "time_series_cv", "matches_df", "n_folds"))

    results <- parLapply(cl, k_range, function(k) {
      library(dplyr)
      brier <- time_series_cv(matches_df, k, n_folds)
      list(k_factor = k, brier_score = brier)
    })

    stopCluster(cl)
  } else {
    results <- list()
    pb <- txtProgressBar(min = 0, max = length(k_range), style = 3)

    for (i in seq_along(k_range)) {
      k <- k_range[i]
      brier <- time_series_cv(matches_df, k, n_folds)
      results[[i]] <- list(k_factor = k, brier_score = brier)
      setTxtProgressBar(pb, i)
    }
    close(pb)
  }

  # Convertir en DataFrame
  results_df <- do.call(rbind, lapply(results, function(x) {
    data.frame(k_factor = x$k_factor, brier_score = x$brier_score)
  }))

  results_df <- results_df %>%
    arrange(brier_score)

  # Meilleur K
  best_k <- results_df$k_factor[1]
  best_brier <- results_df$brier_score[1]

  cat("\n\n=== Résultats ===\n")
  cat(sprintf("K-factor optimal: %d\n", best_k))
  cat(sprintf("Brier score: %.4f\n\n", best_brier))

  cat("Top 5 K-factors:\n")
  print(head(results_df, 5))

  return(list(
    k_optimal = best_k,
    best_brier_score = best_brier,
    all_results = results_df
  ))
}

#' Optimisation bayésienne du K-factor (plus efficace que grid search)
#'
#' @param matches_df DataFrame de matchs
#' @param n_iterations Nombre d'itérations
#' @param k_min K minimum
#' @param k_max K maximum
#' @return K-factor optimal
optimize_k_factor_bayesian <- function(matches_df,
                                        n_iterations = 20,
                                        k_min = 10,
                                        k_max = 50) {

  cat("Optimisation bayésienne du K-factor\n")
  cat("(Implémentation simple - pour version avancée, utiliser package 'rBayesianOptimization')\n\n")

  # Version simplifiée: exploration puis exploitation
  results <- data.frame()

  # Phase 1: Exploration (samples aléatoires)
  n_explore <- 10
  k_values <- sample(k_min:k_max, n_explore, replace = FALSE)

  cat("Phase 1: Exploration...\n")
  pb <- txtProgressBar(min = 0, max = n_explore, style = 3)

  for (i in seq_along(k_values)) {
    k <- k_values[i]
    brier <- time_series_cv(matches_df, k, n_folds = 3)  # Moins de folds pour vitesse
    results <- rbind(results, data.frame(k_factor = k, brier_score = brier))
    setTxtProgressBar(pb, i)
  }
  close(pb)

  # Phase 2: Exploitation (autour du meilleur)
  cat("\nPhase 2: Exploitation...\n")
  n_exploit <- n_iterations - n_explore

  for (i in 1:n_exploit) {
    # Trouver le meilleur K actuel
    best_k <- results$k_factor[which.min(results$brier_score)]

    # Explorer autour du meilleur (± 5)
    k_new <- best_k + sample(-5:5, 1)
    k_new <- max(k_min, min(k_max, k_new))

    # Éviter de tester deux fois le même K
    if (k_new %in% results$k_factor) {
      next
    }

    brier <- time_series_cv(matches_df, k_new, n_folds = 3)
    results <- rbind(results, data.frame(k_factor = k_new, brier_score = brier))

    cat(sprintf("  Iteration %d: K=%d, Brier=%.4f\n", n_explore + i, k_new, brier))
  }

  results <- results %>%
    arrange(brier_score)

  best_k <- results$k_factor[1]
  best_brier <- results$brier_score[1]

  cat("\n=== Résultat final ===\n")
  cat(sprintf("K-factor optimal: %d\n", best_k))
  cat(sprintf("Brier score: %.4f\n", best_brier))

  return(list(
    k_optimal = best_k,
    best_brier_score = best_brier,
    all_results = results
  ))
}
