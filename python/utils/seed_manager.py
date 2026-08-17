"""
Generates a fresh, time-based random seed for each cdc_generator.py run
and persists it to metadata.Generation_Seeds so every day's simulated
data is reproducible/traceable, unlike the fixed RANDOM_SEED used by the
one-time master/transaction generators.
"""

import time
from sqlalchemy import text
from config.database import SQL_SERVER_ENGINE


def get_live_seed():

    seed = time.time_ns()

    with SQL_SERVER_ENGINE.begin() as conn:

        conn.execute(
            text("""
                INSERT INTO metadata.Generation_Seeds
                (
                    generator_name,
                    seed,
                    description
                )
                VALUES
                (
                    'CDC_INSERTS',
                    :seed,
                    'Automatic seed generation'
                )
            """),
            {"seed": seed}
        )

    return seed