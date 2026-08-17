"""
Project-wide logging factory. get_logger(name) returns a configured,
reusable logger that writes to both the console and logs/pipeline.log
with a shared format, and registers its handlers only once per name to
avoid duplicate log lines on repeated calls.
"""

from config.config import PIPELINE_LOGS_PATH, LOG_LEVEL, LOG_FORMAT
import logging
from pathlib import Path


def get_logger(name: str) -> logging.Logger:
    #creating and configuring logger
    logger = logging.getLogger(name)
    logger.propagate = False
    logger.setLevel(LOG_LEVEL)


    #ensuring log directory exists
    Path(PIPELINE_LOGS_PATH).parent.mkdir(parents=True, exist_ok=True)


    # Condition - Add handlers only once to avoid duplicate logs
    if not logger.handlers:

        # handler for Writing logs to a file loc -> /logs/pipeline.logs
        file_handler = logging.FileHandler(PIPELINE_LOGS_PATH, encoding="utf-8")
        file_handler.setFormatter(logging.Formatter(LOG_FORMAT))

        #handler for displaying logs in console
        console_handler = logging.StreamHandler()
        console_handler.setFormatter(logging.Formatter(LOG_FORMAT))

        # Adding/Registering both handlers
        logger.addHandler(file_handler)
        logger.addHandler(console_handler)

    return logger


"""
#testing
if __name__ == "__main__":
    logger = get_logger("test")
    logger.info("Logger initialized successfully!")
"""

