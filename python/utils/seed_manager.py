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