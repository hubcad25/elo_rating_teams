#!/usr/bin/env python3
"""
Script to fetch NHL game data from the official NHL API.

Usage:
    # Fetch all games from 2007-08 to current season
    python scripts/fetch_nhl_data.py

    # Fetch specific season range
    python scripts/fetch_nhl_data.py --start-year 2007 --end-year 2024

    # Fetch single season
    python scripts/fetch_nhl_data.py --start-year 2023 --end-year 2023

    # Specify output file
    python scripts/fetch_nhl_data.py --output data/processed/games_custom.csv
"""

import argparse
import sys
import logging
from pathlib import Path
from datetime import datetime
import json

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from src.data.nhl_api import NHLAPIClient
from src.data.data_collector import NHLDataCollector


def setup_logging(verbose: bool = False):
    """Configure logging."""
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(
        level=level,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )


def main():
    parser = argparse.ArgumentParser(
        description='Fetch NHL game data from official API',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )

    parser.add_argument(
        '--start-year',
        type=int,
        default=2007,
        help='First season start year (default: 2007 for 2007-08 season)'
    )

    parser.add_argument(
        '--end-year',
        type=int,
        default=datetime.now().year,
        help='Last season start year (default: current year)'
    )

    parser.add_argument(
        '--output',
        type=str,
        default='data/processed/nhl_games.csv',
        help='Output CSV file path (default: data/processed/nhl_games.csv)'
    )

    parser.add_argument(
        '--rate-limit',
        type=float,
        default=0.5,
        help='Delay between API requests in seconds (default: 0.5)'
    )

    parser.add_argument(
        '--verbose',
        action='store_true',
        help='Enable verbose logging'
    )

    parser.add_argument(
        '--summary-only',
        action='store_true',
        help='Only show data summary without saving'
    )

    args = parser.parse_args()

    setup_logging(args.verbose)
    logger = logging.getLogger(__name__)

    # Validate year range
    if args.start_year > args.end_year:
        logger.error("start-year must be <= end-year")
        sys.exit(1)

    if args.start_year < 2007:
        logger.warning("Data quality may be inconsistent for seasons before 2007-08")

    # Initialize collector
    logger.info("Initializing NHL data collector...")
    api_client = NHLAPIClient(rate_limit_delay=args.rate_limit)
    collector = NHLDataCollector(api_client=api_client)

    # Collect data
    logger.info(f"Fetching games from {args.start_year}-{args.start_year+1} to {args.end_year}-{args.end_year+1}")
    logger.info("This may take several minutes depending on the number of seasons...")

    try:
        df = collector.collect_multiple_seasons(args.start_year, args.end_year)

        if df.empty:
            logger.error("No data collected. Exiting.")
            sys.exit(1)

        # Show summary
        summary = collector.get_data_summary(df)
        logger.info("\n" + "="*60)
        logger.info("DATA COLLECTION SUMMARY")
        logger.info("="*60)
        logger.info(f"Total games collected: {summary['total_games']}")
        logger.info(f"Seasons: {len(summary['seasons'])}")
        logger.info(f"  First: {summary['seasons'][0]}")
        logger.info(f"  Last: {summary['seasons'][-1]}")
        logger.info(f"Date range: {summary['date_range']['first_game']} to {summary['date_range']['last_game']}")
        logger.info(f"Teams: {len(summary['teams'])}")
        logger.info("Game types:")
        for game_type, count in summary['game_types'].items():
            logger.info(f"  {game_type}: {count}")
        logger.info("="*60)

        # Save data
        if not args.summary_only:
            output_path = Path(args.output)
            output_path.parent.mkdir(parents=True, exist_ok=True)

            collector.save_to_csv(df, str(output_path))
            logger.info(f"\nData successfully saved to: {output_path}")

            # Also save summary as JSON
            summary_path = output_path.parent / f"{output_path.stem}_summary.json"
            with open(summary_path, 'w') as f:
                json.dump(summary, f, indent=2)
            logger.info(f"Summary saved to: {summary_path}")

        logger.info("\nCollection complete!")

    except KeyboardInterrupt:
        logger.warning("\nCollection interrupted by user")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Error during collection: {e}", exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
