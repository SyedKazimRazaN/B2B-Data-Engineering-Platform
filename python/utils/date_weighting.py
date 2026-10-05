"""
weighted_datetime_between(): picks random dates that follow business patterns
(busy Q4, quiet summer, weekdays, office hours) using the weight tables in
constants.py, instead of spreading dates evenly.
"""

import random


def weighted_datetime_between(
    fake,
    start_date,
    end_date,
    month_weights=None,
    dow_weights=None,
    hour_weights=None,
    max_attempts=50,
):
    """
    Draws a random date and keeps it with a chance of weight / highest weight
    (for its month, weekday and hour). The busiest month/day/hour is always kept,
    quieter ones less often, so the data shows the Q4 peak and the summer dip.
    Tries up to max_attempts times, then returns the last date drawn.
    Uses the seeded Faker / random, so the same seed gives the same dates.
    """
    candidate = None
    for _ in range(max_attempts):
        candidate = fake.date_time_between(start_date=start_date, end_date=end_date)

        weight = 1.0
        if month_weights:
            weight *= month_weights.get(candidate.month, 100) / max(month_weights.values())
        if dow_weights:
            weight *= dow_weights.get(candidate.weekday(), 100) / max(dow_weights.values())
        if hour_weights:
            weight *= hour_weights.get(candidate.hour, 100) / max(hour_weights.values())

        if random.random() <= weight:
            return candidate

    # Fall back to the last candidate after max_attempts so callers always
    # get a value within [start_date, end_date] even in worst-case sampling.
    return candidate
