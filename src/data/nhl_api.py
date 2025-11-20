"""
NHL API client for fetching game data from the official NHL API.
"""

import requests
import time
from typing import List, Dict, Optional
from datetime import datetime
import logging

logger = logging.getLogger(__name__)


class NHLAPIClient:
    """Client for interacting with the NHL web API."""

    BASE_URL = "https://api-web.nhle.com/v1"

    # Current active NHL teams (as of 2024-25)
    CURRENT_TEAMS = [
        "ANA", "BOS", "BUF", "CAR", "CBJ", "CGY", "CHI", "COL", "DAL", "DET",
        "EDM", "FLA", "LAK", "MIN", "MTL", "NJD", "NSH", "NYI", "NYR", "OTT",
        "PHI", "PIT", "SEA", "SJS", "STL", "TBL", "TOR", "UTA", "VAN", "VGK",
        "WPG", "WSH"
    ]

    # Historical teams that relocated or changed names
    HISTORICAL_TEAMS = {
        "ATL": (2007, 2011),  # Atlanta Thrashers (moved to Winnipeg in 2011-12)
        "PHX": (2007, 2014),  # Phoenix Coyotes (became Arizona in 2014-15)
        "ARI": (2014, 2024),  # Arizona Coyotes (became Utah in 2024-25)
    }

    def __init__(self, rate_limit_delay: float = 0.5):
        """
        Initialize NHL API client.

        Args:
            rate_limit_delay: Delay in seconds between API requests to avoid rate limiting
        """
        self.rate_limit_delay = rate_limit_delay
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'NHL-Elo-Rating-System/1.0'
        })

    def _make_request(self, endpoint: str, max_retries: int = 3) -> Optional[Dict]:
        """
        Make HTTP request to NHL API with retry logic.

        Args:
            endpoint: API endpoint path
            max_retries: Number of retry attempts on failure

        Returns:
            JSON response as dictionary or None if request failed
        """
        url = f"{self.BASE_URL}{endpoint}"

        for attempt in range(max_retries):
            try:
                time.sleep(self.rate_limit_delay)
                response = self.session.get(url, timeout=10)
                response.raise_for_status()
                return response.json()
            except requests.exceptions.RequestException as e:
                logger.warning(f"Request failed (attempt {attempt + 1}/{max_retries}): {e}")
                if attempt == max_retries - 1:
                    logger.error(f"Failed to fetch {url} after {max_retries} attempts")
                    return None
                time.sleep(2 ** attempt)  # Exponential backoff

        return None

    def get_team_schedule(self, team_code: str, season: int) -> Optional[Dict]:
        """
        Get full season schedule for a team.

        Args:
            team_code: Three-letter team code (e.g., 'TOR', 'MTL')
            season: Season in YYYYYYYY format (e.g., 20232024)

        Returns:
            JSON response with all games for the team in that season
        """
        endpoint = f"/club-schedule-season/{team_code}/{season}"
        logger.info(f"Fetching schedule for {team_code} season {season}")
        return self._make_request(endpoint)

    def get_all_teams_for_season(self, season: int) -> List[str]:
        """
        Get list of all active teams for a given season.

        Args:
            season: Season in YYYYYYYY format (e.g., 20232024)

        Returns:
            List of three-letter team codes active in that season
        """
        season_year = season // 10000  # Extract start year (e.g., 2023 from 20232024)

        teams = list(self.CURRENT_TEAMS)

        # Add historical teams if they were active during this season
        for team_code, (start_year, end_year) in self.HISTORICAL_TEAMS.items():
            if start_year <= season_year <= end_year:
                teams.append(team_code)

        # Remove teams that didn't exist yet
        if season_year < 2017:
            teams = [t for t in teams if t != "VGK"]  # Vegas joined 2017-18
        if season_year < 2021:
            teams = [t for t in teams if t != "SEA"]  # Seattle joined 2021-22
        if season_year < 2024:
            teams = [t for t in teams if t != "UTA"]  # Utah joined 2024-25

        return sorted(teams)

    @staticmethod
    def format_season(start_year: int) -> int:
        """
        Convert start year to NHL season format.

        Args:
            start_year: Starting year of season (e.g., 2023 for 2023-24 season)

        Returns:
            Season in YYYYYYYY format (e.g., 20232024)
        """
        return start_year * 10000 + (start_year + 1)

    @staticmethod
    def parse_game(game: Dict) -> Optional[Dict]:
        """
        Parse game data from API response into standardized format.

        Args:
            game: Game dictionary from API response

        Returns:
            Parsed game data or None if game is not finished
        """
        # Only include finished games
        game_state = game.get("gameState", "")
        if game_state not in ["FINAL", "OFF"]:
            return None

        game_type = game.get("gameType", 0)

        # Filter out preseason games (gameType == 1)
        if game_type == 1:
            return None

        # Determine game type label
        if game_type == 2:
            game_type_label = "regular"
        elif game_type == 3:
            game_type_label = "playoffs"
        else:
            logger.warning(f"Unknown game type {game_type} for game {game.get('id')}")
            return None

        try:
            home_team = game["homeTeam"]
            away_team = game["awayTeam"]

            parsed = {
                "game_id": game["id"],
                "season": game["season"],
                "game_type": game_type_label,
                "game_date": game["gameDate"],
                "home_team": home_team["abbrev"],
                "away_team": away_team["abbrev"],
                "home_score": home_team.get("score", 0),
                "away_score": away_team.get("score", 0),
            }

            return parsed

        except KeyError as e:
            logger.error(f"Failed to parse game {game.get('id')}: missing key {e}")
            return None
