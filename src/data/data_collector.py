"""
Data collector for fetching all NHL game data across multiple seasons.
"""

import pandas as pd
from typing import List, Dict, Set
import logging
from tqdm import tqdm

from .nhl_api import NHLAPIClient

logger = logging.getLogger(__name__)


class NHLDataCollector:
    """Collector for fetching NHL game data across seasons."""

    def __init__(self, api_client: NHLAPIClient = None):
        """
        Initialize data collector.

        Args:
            api_client: NHL API client instance (creates new one if None)
        """
        self.api = api_client or NHLAPIClient()

    def collect_season_games(self, season: int) -> pd.DataFrame:
        """
        Collect all games for a single season.

        Args:
            season: Season in YYYYYYYY format (e.g., 20232024)

        Returns:
            DataFrame with all games from that season
        """
        teams = self.api.get_all_teams_for_season(season)
        logger.info(f"Collecting games for season {season} ({len(teams)} teams)")

        all_games = []
        seen_game_ids: Set[int] = set()

        for team in tqdm(teams, desc=f"Season {season}"):
            schedule = self.api.get_team_schedule(team, season)

            if schedule is None:
                logger.warning(f"Failed to fetch schedule for {team} in season {season}")
                continue

            games = schedule.get("games", [])

            for game in games:
                parsed_game = self.api.parse_game(game)

                if parsed_game is None:
                    continue

                game_id = parsed_game["game_id"]

                # Avoid duplicates (each game appears in both teams' schedules)
                if game_id not in seen_game_ids:
                    seen_game_ids.add(game_id)
                    all_games.append(parsed_game)

        df = pd.DataFrame(all_games)

        if not df.empty:
            # Sort by game date and game_id
            df = df.sort_values(["game_date", "game_id"]).reset_index(drop=True)
            logger.info(f"Collected {len(df)} games for season {season}")
        else:
            logger.warning(f"No games found for season {season}")

        return df

    def collect_multiple_seasons(
        self, start_year: int, end_year: int
    ) -> pd.DataFrame:
        """
        Collect all games across multiple seasons.

        Args:
            start_year: First season start year (e.g., 2007 for 2007-08)
            end_year: Last season start year (e.g., 2024 for 2024-25)

        Returns:
            DataFrame with all games from all seasons
        """
        all_seasons_data = []

        for year in range(start_year, end_year + 1):
            season = self.api.format_season(year)
            season_df = self.collect_season_games(season)

            if not season_df.empty:
                all_seasons_data.append(season_df)

        if all_seasons_data:
            combined_df = pd.concat(all_seasons_data, ignore_index=True)
            logger.info(f"Total games collected: {len(combined_df)}")
            return combined_df
        else:
            logger.error("No games collected")
            return pd.DataFrame()

    def save_to_csv(self, df: pd.DataFrame, output_path: str):
        """
        Save games DataFrame to CSV file.

        Args:
            df: DataFrame with game data
            output_path: Path to output CSV file
        """
        if df.empty:
            logger.warning("DataFrame is empty, not saving")
            return

        df.to_csv(output_path, index=False)
        logger.info(f"Saved {len(df)} games to {output_path}")

    def get_data_summary(self, df: pd.DataFrame) -> Dict:
        """
        Get summary statistics of collected data.

        Args:
            df: DataFrame with game data

        Returns:
            Dictionary with summary statistics
        """
        if df.empty:
            return {"total_games": 0}

        summary = {
            "total_games": len(df),
            "seasons": sorted(df["season"].unique().tolist()),
            "game_types": df["game_type"].value_counts().to_dict(),
            "teams": sorted(df["home_team"].unique().tolist()),
            "date_range": {
                "first_game": df["game_date"].min(),
                "last_game": df["game_date"].max(),
            },
        }

        return summary
