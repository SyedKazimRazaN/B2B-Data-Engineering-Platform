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
    Rejection-samples fake.date_time_between() toward realistic
    seasonal / weekly / hourly patterns, without breaking deterministic
    seeding (still driven entirely by `fake`'s seeded RNG + `random`,
    both of which are seeded once at generator startup).

    Each weight table maps candidate.month / candidate.weekday() / candidate.hour
    to a weight around 100 (100 = baseline, >100 = boosted, <100 = suppressed).
    """
    candidate = None
    for _ in range(max_attempts):
        candidate = fake.date_time_between(start_date=start_date, end_date=end_date)

        weight = 1.0
        if month_weights:
            weight *= month_weights.get(candidate.month, 100) / 100
        if dow_weights:
            weight *= dow_weights.get(candidate.weekday(), 100) / 100
        if hour_weights:
            weight *= hour_weights.get(candidate.hour, 100) / 100

        if random.random() <= weight:
            return candidate

    # Fall back to the last candidate after max_attempts so callers always
    # get a value within [start_date, end_date] even in worst-case sampling.
    return candidate