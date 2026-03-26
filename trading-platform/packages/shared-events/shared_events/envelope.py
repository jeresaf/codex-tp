from pydantic import BaseModel
from typing import Any


class EventEnvelope(BaseModel):
    event_id: str
    event_type: str
    event_version: int
    source_service: str
    environment: str
    occurred_at: str
    correlation_id: str | None = None
    causation_id: str | None = None
    actor_type: str = "system"
    actor_id: str | None = None
    payload: dict[str, Any]
