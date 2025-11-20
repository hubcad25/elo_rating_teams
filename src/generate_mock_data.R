# Génère des données fictives de matchs NHL pour tester le système Elo
# Simule des saisons réalistes depuis 2007-08

library(dplyr)
library(lubridate)

#' Génère des données fictives de matchs NHL
#'
#' @param start_season Première saison à générer (ex: "2007-08")
#' @param end_season Dernière saison à générer (ex: "2024-25")
#' @param teams Vecteur des noms d'équipes (défaut = 32 équipes actuelles)
#' @return DataFrame avec: date, home_team, away_team, home_score, away_score, season
generate_mock_nhl_data <- function(start_season = "2007-08",
                                    end_season = "2024-25",
                                    teams = NULL) {

  # Équipes NHL actuelles (32 équipes)
  if (is.null(teams)) {
    teams <- c(
      "Anaheim Ducks", "Arizona Coyotes", "Boston Bruins", "Buffalo Sabres",
      "Calgary Flames", "Carolina Hurricanes", "Chicago Blackhawks",
      "Colorado Avalanche", "Columbus Blue Jackets", "Dallas Stars",
      "Detroit Red Wings", "Edmonton Oilers", "Florida Panthers",
      "Los Angeles Kings", "Minnesota Wild", "Montreal Canadiens",
      "Nashville Predators", "New Jersey Devils", "New York Islanders",
      "New York Rangers", "Ottawa Senators", "Philadelphia Flyers",
      "Pittsburgh Penguins", "San Jose Sharks", "Seattle Kraken",
      "St. Louis Blues", "Tampa Bay Lightning", "Toronto Maple Leafs",
      "Vancouver Canucks", "Vegas Golden Knights", "Washington Capitals",
      "Winnipeg Jets"
    )
  }

  # Parser les saisons
  start_year <- as.integer(substr(start_season, 1, 4))
  end_year <- as.integer(substr(end_season, 1, 4))

  all_matches <- data.frame()

  for (year in start_year:end_year) {
    season_label <- paste0(year, "-", substr(year + 1, 3, 4))

    # Saison régulière: octobre à avril
    season_start <- ymd(paste0(year, "-10-01"))
    season_end <- ymd(paste0(year + 1, "-04-15"))

    # Nombre de matchs par équipe en saison régulière: 82
    # Total de matchs: 32 * 82 / 2 = 1312 matchs
    n_matches <- 1300

    # Générer des dates de matchs réalistes
    match_dates <- sample(seq(season_start, season_end, by = "day"),
                          size = n_matches, replace = TRUE)
    match_dates <- sort(match_dates)

    # Générer des matchups aléatoires
    home_teams <- sample(teams, n_matches, replace = TRUE)
    away_teams <- sample(teams, n_matches, replace = TRUE)

    # S'assurer qu'une équipe ne joue pas contre elle-même
    same_team <- home_teams == away_teams
    while (any(same_team)) {
      away_teams[same_team] <- sample(teams, sum(same_team), replace = TRUE)
      same_team <- home_teams == away_teams
    }

    # Générer des scores réalistes
    # NHL: moyenne ~3 buts par équipe, distribution Poisson
    # Avantage domicile: +0.3 buts en moyenne
    home_scores <- rpois(n_matches, lambda = 3.2)
    away_scores <- rpois(n_matches, lambda = 2.9)

    # S'assurer qu'il n'y a pas de nulles (overtime/shootout décide toujours)
    tied <- home_scores == away_scores
    while (any(tied)) {
      # Ajouter un but à l'une des deux équipes aléatoirement
      winner <- sample(c(TRUE, FALSE), sum(tied), replace = TRUE)
      home_scores[tied][winner] <- home_scores[tied][winner] + 1
      away_scores[tied][!winner] <- away_scores[tied][!winner] + 1
      tied <- home_scores == away_scores
    }

    # Créer le DataFrame de la saison
    season_matches <- data.frame(
      date = match_dates,
      season = season_label,
      home_team = home_teams,
      away_team = away_teams,
      home_score = home_scores,
      away_score = away_scores,
      stringsAsFactors = FALSE
    )

    all_matches <- rbind(all_matches, season_matches)
  }

  # Trier par date
  all_matches <- all_matches %>%
    arrange(date)

  return(all_matches)
}

#' Génère des données avec des équipes de forces différentes (plus réaliste)
#'
#' @param start_season Première saison
#' @param end_season Dernière saison
#' @return DataFrame de matchs avec résultats biaisés selon force des équipes
generate_realistic_mock_data <- function(start_season = "2007-08",
                                         end_season = "2024-25") {

  # Équipes avec leurs "vraies" forces relatives (arbitraires mais réalistes)
  teams_strength <- data.frame(
    team = c(
      "Tampa Bay Lightning", "Colorado Avalanche", "Boston Bruins",
      "Florida Panthers", "Vegas Golden Knights", "Carolina Hurricanes",
      "Toronto Maple Leafs", "Edmonton Oilers", "New York Rangers",
      "Dallas Stars", "Minnesota Wild", "Los Angeles Kings",
      "Calgary Flames", "Winnipeg Jets", "Washington Capitals",
      "Pittsburgh Penguins", "Nashville Predators", "Vancouver Canucks",
      "St. Louis Blues", "New Jersey Devils", "New York Islanders",
      "Seattle Kraken", "Ottawa Senators", "Montreal Canadiens",
      "Philadelphia Flyers", "Detroit Red Wings", "Buffalo Sabres",
      "San Jose Sharks", "Columbus Blue Jackets", "Anaheim Ducks",
      "Arizona Coyotes", "Chicago Blackhawks"
    ),
    strength = c(
      0.65, 0.63, 0.62, 0.60, 0.59, 0.58, 0.57, 0.56, 0.55, 0.54,
      0.53, 0.52, 0.51, 0.50, 0.50, 0.49, 0.49, 0.48, 0.48, 0.47,
      0.47, 0.46, 0.45, 0.44, 0.43, 0.42, 0.41, 0.40, 0.39, 0.38,
      0.36, 0.35
    ),
    stringsAsFactors = FALSE
  )

  start_year <- as.integer(substr(start_season, 1, 4))
  end_year <- as.integer(substr(end_season, 1, 4))

  all_matches <- data.frame()

  for (year in start_year:end_year) {
    season_label <- paste0(year, "-", substr(year + 1, 3, 4))
    season_start <- ymd(paste0(year, "-10-01"))
    season_end <- ymd(paste0(year + 1, "-04-15"))

    n_matches <- 1300
    match_dates <- sample(seq(season_start, season_end, by = "day"),
                          size = n_matches, replace = TRUE)
    match_dates <- sort(match_dates)

    home_teams <- sample(teams_strength$team, n_matches, replace = TRUE)
    away_teams <- sample(teams_strength$team, n_matches, replace = TRUE)

    same_team <- home_teams == away_teams
    while (any(same_team)) {
      away_teams[same_team] <- sample(teams_strength$team, sum(same_team), replace = TRUE)
      same_team <- home_teams == away_teams
    }

    # Obtenir les forces
    home_strength <- teams_strength$strength[match(home_teams, teams_strength$team)]
    away_strength <- teams_strength$strength[match(away_teams, teams_strength$team)]

    # Avantage domicile
    home_advantage <- 0.08

    # Probabilité de victoire à domicile basée sur les forces
    home_win_prob <- home_strength + home_advantage - away_strength * 0.5

    # Générer les résultats basés sur ces probabilités
    home_wins <- runif(n_matches) < home_win_prob

    # Scores réalistes
    home_scores <- rpois(n_matches, lambda = 3.0 + home_strength * 2)
    away_scores <- rpois(n_matches, lambda = 2.8 + away_strength * 2)

    # Ajuster pour refléter le vainqueur
    home_scores[home_wins & home_scores <= away_scores[home_wins]] <-
      away_scores[home_wins & home_scores <= away_scores[home_wins]] + 1
    away_scores[!home_wins & away_scores <= home_scores[!home_wins]] <-
      home_scores[!home_wins & away_scores <= home_scores[!home_wins]] + 1

    season_matches <- data.frame(
      date = match_dates,
      season = season_label,
      home_team = home_teams,
      away_team = away_teams,
      home_score = home_scores,
      away_score = away_scores,
      stringsAsFactors = FALSE
    )

    all_matches <- rbind(all_matches, season_matches)
  }

  all_matches <- all_matches %>%
    arrange(date)

  return(all_matches)
}

#' Sauvegarde les données mockées
#'
#' @param data DataFrame de matchs
#' @param filename Nom du fichier (défaut: mock_nhl_games.csv)
save_mock_data <- function(data, filename = "data/raw/mock_nhl_games.csv") {
  write_csv(data, filename)
  cat("Données sauvegardées:", filename, "\n")
  cat("Nombre de matchs:", nrow(data), "\n")
  cat("Saisons:", min(data$season), "à", max(data$season), "\n")
  cat("Équipes uniques:", length(unique(c(data$home_team, data$away_team))), "\n")
}
