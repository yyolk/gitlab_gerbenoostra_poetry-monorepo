import logging

logger = logging.getLogger(__name__)


def handler(event, context):  # noqa: C901
    """Entrypoint for lambda."""
    logging.getLogger().setLevel(logging.INFO)
    return handle_event(event)


def handle_event(event):
    """Actually handle the event."""
    logger.info(f"handling event {event}")
    return {"result": "success"}
