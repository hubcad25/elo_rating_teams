# Visualisations pour le système Elo NHL

library(ggplot2)
library(dplyr)
library(lubridate)
library(scales)

# Thème personnalisé pour les graphiques
theme_nhl <- function() {
  theme_minimal() +
    theme(
      plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
      plot.subtitle = element_text(size = 12, hjust = 0.5, color = "gray40"),
      axis.title = element_text(size = 12, face = "bold"),
      axis.text = element_text(size = 10),
      legend.position = "bottom",
      legend.title = element_text(face = "bold"),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(color = "gray90")
    )
}

#' Graphique de l'évolution des ratings dans le temps
#'
#' @param ratings_history DataFrame de l'historique
#' @param teams Vecteur des équipes à afficher (si NULL, affiche top 10)
#' @param title Titre du graphique
#' @return ggplot object
plot_rating_evolution <- function(ratings_history,
                                   teams = NULL,
                                   title = "Évolution des ratings Elo NHL") {

  if (is.null(teams)) {
    # Prendre les 10 équipes avec le meilleur rating final
    final_ratings <- ratings_history %>%
      group_by(team) %>%
      filter(date == max(date)) %>%
      arrange(desc(rating_after)) %>%
      head(10)

    teams <- final_ratings$team
  }

  plot_data <- ratings_history %>%
    filter(team %in% teams)

  ggplot(plot_data, aes(x = date, y = rating_after, color = team)) +
    geom_line(linewidth = 1, alpha = 0.8) +
    scale_color_viridis_d(option = "turbo") +
    scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
    labs(
      title = title,
      subtitle = sprintf("Top %d équipes par rating final", length(teams)),
      x = "Date",
      y = "Rating Elo",
      color = "Équipe"
    ) +
    theme_nhl() +
    guides(color = guide_legend(ncol = 2))
}

#' Graphique des ratings finaux (barplot)
#'
#' @param final_ratings DataFrame des ratings finaux
#' @param n_teams Nombre d'équipes à afficher
#' @return ggplot object
plot_final_ratings <- function(final_ratings, n_teams = 20) {

  plot_data <- final_ratings %>%
    head(n_teams) %>%
    mutate(team = reorder(team, rating))

  ggplot(plot_data, aes(x = rating, y = team, fill = rating)) +
    geom_col() +
    scale_fill_gradient2(
      low = "#d73027",
      mid = "#fee090",
      high = "#1a9850",
      midpoint = 1500,
      guide = "none"
    ) +
    geom_vline(xintercept = 1500, linetype = "dashed", color = "gray40") +
    labs(
      title = "Rankings Elo NHL - Ratings finaux",
      subtitle = sprintf("Top %d équipes", n_teams),
      x = "Rating Elo",
      y = NULL
    ) +
    theme_nhl() +
    theme(axis.text.y = element_text(size = 9))
}

#' Distribution des résultats attendus vs réels
#'
#' @param ratings_history DataFrame de l'historique
#' @return ggplot object
plot_calibration <- function(ratings_history) {

  # Créer des bins de probabilités
  calibration_data <- ratings_history %>%
    mutate(prob_bin = cut(expected_win_prob,
                          breaks = seq(0, 1, by = 0.1),
                          include.lowest = TRUE)) %>%
    group_by(prob_bin) %>%
    summarise(
      predicted = mean(expected_win_prob),
      actual = mean(actual_result),
      n = n()
    ) %>%
    filter(!is.na(prob_bin))

  ggplot(calibration_data, aes(x = predicted, y = actual)) +
    geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "gray40") +
    geom_point(aes(size = n), alpha = 0.7, color = "#0072B2") +
    geom_smooth(method = "loess", se = FALSE, color = "#D55E00") +
    scale_size_continuous(name = "Nombre de matchs") +
    coord_fixed(xlim = c(0, 1), ylim = c(0, 1)) +
    labs(
      title = "Calibration du modèle Elo",
      subtitle = "Prédictions vs Résultats réels",
      x = "Probabilité prédite",
      y = "Fréquence réelle de victoire"
    ) +
    theme_nhl()
}

#' Distribution des erreurs de prédiction
#'
#' @param ratings_history DataFrame de l'historique
#' @return ggplot object
plot_prediction_errors <- function(ratings_history) {

  error_data <- ratings_history %>%
    mutate(error = expected_win_prob - actual_result)

  ggplot(error_data, aes(x = error)) +
    geom_histogram(bins = 50, fill = "#0072B2", color = "white", alpha = 0.8) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "red", linewidth = 1) +
    labs(
      title = "Distribution des erreurs de prédiction",
      subtitle = "Probabilité prédite - Résultat réel",
      x = "Erreur de prédiction",
      y = "Fréquence"
    ) +
    theme_nhl()
}

#' Évolution des ratings par saison
#'
#' @param ratings_history DataFrame de l'historique avec colonne season
#' @param teams Équipes à afficher
#' @return ggplot object
plot_rating_by_season <- function(ratings_history, teams) {

  # Calculer le rating moyen par saison pour chaque équipe
  season_data <- ratings_history %>%
    filter(team %in% teams) %>%
    mutate(season = substr(as.character(date), 1, 4)) %>%
    group_by(team, season) %>%
    summarise(
      mean_rating = mean(rating_after),
      final_rating = last(rating_after),
      .groups = "drop"
    )

  ggplot(season_data, aes(x = season, y = final_rating, color = team, group = team)) +
    geom_line(linewidth = 1.2, alpha = 0.8) +
    geom_point(size = 2) +
    scale_color_viridis_d(option = "turbo") +
    labs(
      title = "Évolution des ratings par saison",
      subtitle = "Rating en fin de saison régulière",
      x = "Saison",
      y = "Rating Elo",
      color = "Équipe"
    ) +
    theme_nhl() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
}

#' Matrice de comparaison entre équipes
#'
#' @param final_ratings DataFrame des ratings finaux
#' @param top_n Nombre d'équipes à comparer
#' @return ggplot object
plot_matchup_matrix <- function(final_ratings, top_n = 16) {

  top_teams <- final_ratings %>%
    head(top_n)

  # Créer une matrice de probabilités
  matchup_data <- expand.grid(
    home = top_teams$team,
    away = top_teams$team,
    stringsAsFactors = FALSE
  ) %>%
    filter(home != away)

  # Calculer les probabilités
  matchup_data <- matchup_data %>%
    left_join(top_teams, by = c("home" = "team")) %>%
    rename(home_rating = rating) %>%
    left_join(top_teams, by = c("away" = "team")) %>%
    rename(away_rating = rating) %>%
    mutate(
      home_win_prob = 1 / (1 + 10^((away_rating - home_rating) / 400))
    )

  ggplot(matchup_data, aes(x = home, y = away, fill = home_win_prob)) +
    geom_tile(color = "white") +
    geom_text(aes(label = sprintf("%.0f%%", home_win_prob * 100)),
              size = 2.5, color = "black") +
    scale_fill_gradient2(
      low = "#d73027",
      mid = "#ffffbf",
      high = "#1a9850",
      midpoint = 0.5,
      name = "Prob victoire\néquipe locale",
      labels = percent
    ) +
    labs(
      title = "Matrice des matchups",
      subtitle = sprintf("Probabilités de victoire (Top %d équipes)", top_n),
      x = "Équipe à domicile",
      y = "Équipe visiteuse"
    ) +
    theme_nhl() +
    theme(
      axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5, size = 7),
      axis.text.y = element_text(size = 7)
    )
}

#' Sauvegarder tous les graphiques
#'
#' @param elo_results Résultats du calcul Elo
#' @param output_dir Dossier de sortie
save_all_plots <- function(elo_results, output_dir = "plots") {

  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

  cat("Génération des visualisations...\n")

  # 1. Évolution des ratings
  p1 <- plot_rating_evolution(elo_results$ratings_history)
  ggsave(file.path(output_dir, "rating_evolution.png"),
         p1, width = 12, height = 7, dpi = 300)
  cat("  ✓ rating_evolution.png\n")

  # 2. Ratings finaux
  p2 <- plot_final_ratings(elo_results$final_ratings, n_teams = 32)
  ggsave(file.path(output_dir, "final_ratings.png"),
         p2, width = 10, height = 12, dpi = 300)
  cat("  ✓ final_ratings.png\n")

  # 3. Calibration
  p3 <- plot_calibration(elo_results$ratings_history)
  ggsave(file.path(output_dir, "calibration.png"),
         p3, width = 8, height = 8, dpi = 300)
  cat("  ✓ calibration.png\n")

  # 4. Erreurs de prédiction
  p4 <- plot_prediction_errors(elo_results$ratings_history)
  ggsave(file.path(output_dir, "prediction_errors.png"),
         p4, width = 10, height = 6, dpi = 300)
  cat("  ✓ prediction_errors.png\n")

  # 5. Matrice des matchups
  p5 <- plot_matchup_matrix(elo_results$final_ratings, top_n = 16)
  ggsave(file.path(output_dir, "matchup_matrix.png"),
         p5, width = 12, height = 11, dpi = 300)
  cat("  ✓ matchup_matrix.png\n")

  cat(sprintf("\nTous les graphiques sauvegardés dans '%s/'\n", output_dir))
}
