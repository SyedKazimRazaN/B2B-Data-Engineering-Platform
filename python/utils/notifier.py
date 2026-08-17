"""
Windows toast notification helper used by run_pipeline.py to surface
pipeline success/failure without interrupting the run.
"""

from python.utils.logger import get_logger

logger = get_logger(__name__)


def notify(title, message, duration=5):
    """
    Fire a local Windows toast notification for pipeline success/failure.
    Fails silently (logs a warning, never raises) so a notification
    problem can never take down the actual pipeline run.
    """
    try:
        from win10toast import ToastNotifier

        toaster = ToastNotifier()
        toaster.show_toast(title=title, msg=message, duration=duration, threaded=True)

    except Exception as e:
        logger.warning(f"Notification failed: {e}")