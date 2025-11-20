# NHL Elo Rating System
# Calcule les ratings Elo de façon continue depuis 2007-08
# Approche: Pas de reset entre saisons (continuous)

library(dplyr)
library(lubridate)
library(readr)

# ============================================================================
# CONSTANTES
# ============================================================================

INITIAL_RATING <- 1500
DEFAULT_K_FACTOR <- 20

# ============================================================================
# FONCTIONS ELO
# ============================================================================

#' Calcule la probabilité de victoire attendue (Expected Score)
#'
#' @param rating_a Rating Elo de l'équipe A
#' @param rating_b Rating Elo de l'équipe B
#' @return Probabilité que A batte B (entre 0 et 1)
expected_score <- function(rating_a, rating_b) {
  1 / (1 + 10^((rating_b - rating_a) / 400))
}

#' Met à jour le rating Elo après un match
#'
#' @param old_rating Rating actuel de l'équipe
#' @param expected Probabilité de victoire attendue
#' @param actual Résultat réel (1 = victoire, 0 = défaite, 0.5 = nulle)
#' @param k K-factor (importance de la mise à jour)
#' @return Nouveau rating
update_rating <- function(old_rating, expected, actual, k = DEFAULT_K_FACTOR) {
  old_rating + k * (actual - expected)
}

# ============================================================================
# CALCUL DES RATINGS ELO
# ============================================================================

#' Calcule les ratings Elo pour tous les matchs
#'
#' @param matches_df DataFrame avec colonnes: date, home_team, away_team, home_score, away_score
#' @param k_factor K-factor à utiliser (défaut = 20)
#' @param initial_rating Rating initial pour toutes les équipes (défaut = 1500)
#' @param continuous Si TRUE, ratings persistent entre saisons (défaut = TRUE)
#' @return Liste avec: ratings_history (historique complet), final_ratings (ratings finaux)
calculate_elo_ratings <- function(matches_df,
                                   k_factor = DEFAULT_K_FACTOR,
                                   initial_rating = INITIAL_RATING,
                                   continuous = TRUE) {

  # Trier les matchs par date (crucial!)
  matches_df <- matches_df %>%
    arrange(date)

  # Initialiser les ratings (hash map pour accès rapide)
  ratings <- list()
  all_teams <- unique(c(matches_df$home_team, matches_df$away_team))
  for (team in all_teams) {
    ratings[[team]] <- initial_rating
  }

  # Historique des ratings (pour visualisation et analyse)
  history <- data.frame()

  # Parcourir chaque match dans l'ordre chronologique
  for (i in 1:nrow(matches_df)) {
    match <- matches_df[i, ]

    home_team <- match$home_team
    away_team <- match$away_team
    home_score <- match$home_score
    away_score <- match$away_score
    match_date <- match$date

    # Ratings avant le match
    rating_home <- ratings[[home_team]]
    rating_away <- ratings[[away_team]]

    # Probabilités attendues
    expected_home <- expected_score(rating_home, rating_away)
    expected_away <- 1 - expected_home

    # Résultat réel (1 = victoire, 0 = défaite)
    # Note: Pour l'instant on ignore les nulles (overtime/shootout = victoire)
    actual_home <- ifelse(home_score > away_score, 1, 0)
    actual_away <- ifelse(away_score > home_score, 1, 0)

    # Nouveaux ratings
    new_rating_home <- update_rating(rating_home, expected_home, actual_home, k_factor)
    new_rating_away <- update_rating(rating_away, expected_away, actual_away, k_factor)

    # Sauvegarder dans l'historique
    history <- rbind(history, data.frame(
      date = match_date,
      team = home_team,
      rating_before = rating_home,
      rating_after = new_rating_home,
      expected_win_prob = expected_home,
      actual_result = actual_home,
      opponent = away_team,
      location = "home",
      stringsAsFactors = FALSE
    ))

    history <- rbind(history, data.frame(
      date = match_date,
      team = away_team,
      rating_before = rating_away,
      rating_after = new_rating_away,
      expected_win_prob = expected_away,
      actual_result = actual_away,
      opponent = home_team,
      location = "away",
      stringsAsFactors = FALSE
    ))

    # Mettre à jour les ratings
    ratings[[home_team]] <- new_rating_home
    ratings[[away_team]] <- new_rating_away
  }

  # Convertir les ratings finaux en DataFrame
  final_ratings <- data.frame(
    team = names(ratings),
    rating = unlist(ratings),
    stringsAsFactors = FALSE
  ) %>%
    arrange(desc(rating))

  return(list(
    ratings_history = history,
    final_ratings = final_ratings,
    k_factor_used = k_factor
  ))
}

# ============================================================================
# PRÉDICTIONS
# ============================================================================

#' Prédit le résultat d'un match futur
#'
#' @param home_team Nom de l'équipe à domicile
#' @param away_team Nom de l'équipe à l'extérieur
#' @param current_ratings DataFrame des ratings actuels
#' @return Liste avec probabilités de victoire pour chaque équipe
predict_match <- function(home_team, away_team, current_ratings) {

  rating_home <- current_ratings %>%
    filter(team == home_team) %>%
    pull(rating)

  rating_away <- current_ratings %>%
    filter(team == away_team) %>%
    pull(rating)

  if (length(rating_home) == 0 || length(rating_away) == 0) {
    stop("Une ou les deux équipes n'existent pas dans les ratings")
  }

  prob_home <- expected_score(rating_home, rating_away)
  prob_away <- 1 - prob_home

  return(list(
    home_team = home_team,
    away_team = away_team,
    home_win_prob = prob_home,
    away_win_prob = prob_away,
    rating_home = rating_home,
    rating_away = rating_away
  ))
}

# ============================================================================
# ÉVALUATION DES PRÉDICTIONS
# ============================================================================

#' Calcule le Brier Score (plus bas = meilleur)
#'
#' @param history DataFrame avec expected_win_prob et actual_result
#' @return Brier score moyen
calculate_brier_score <- function(history) {
  mean((history$expected_win_prob - history$actual_result)^2)
}

#' Calcule l'accuracy (% de prédictions correctes)
#'
#' @param history DataFrame avec expected_win_prob et actual_result
#' @return Accuracy (entre 0 et 1)
calculate_accuracy <- function(history) {
  predictions <- ifelse(history$expected_win_prob > 0.5, 1, 0)
  mean(predictions == history$actual_result)
}

#' Calcule le Log Loss
#'
#' @param history DataFrame avec expected_win_prob et actual_result
#' @return Log loss moyen
calculate_log_loss <- function(history) {
  # Éviter log(0) en clippant les probabilités
  probs <- pmax(pmin(history$expected_win_prob, 0.9999), 0.0001)
  -mean(history$actual_result * log(probs) +
          (1 - history$actual_result) * log(1 - probs))
}

#' Résumé complet des métriques de performance
#'
#' @param history DataFrame avec expected_win_prob et actual_result
#' @return DataFrame avec toutes les métriques
evaluate_predictions <- function(history) {
  data.frame(
    brier_score = calculate_brier_score(history),
    accuracy = calculate_accuracy(history),
    log_loss = calculate_log_loss(history),
    n_matches = nrow(history) / 2  # Divisé par 2 car chaque match = 2 lignes
  )
}

# ============================================================================
# NOTES POUR AMÉLIORATIONS FUTURES
# ============================================================================

# TODO: Ajouter variable de continuité du roster
# - % du roster identique à la dernière game
# - Pourrait servir à ajuster dynamiquement le K-factor
# - K_adjusted = K_base * (1 + roster_turnover_factor)
# - Nécessite données des lineups par match

# TODO: Considérer l'avantage domicile
# - Ajouter un bonus de ~50 points Elo pour l'équipe à domicile
# - Ou calculer l'avantage domicile empiriquement

# TODO: Différencier saison régulière vs playoffs
# - K-factor plus élevé en playoffs?
# - Ou ratings séparés?
