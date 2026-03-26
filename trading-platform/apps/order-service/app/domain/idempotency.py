import uuid
from app.db.models import IdempotencyKeyModel


def get_idempotent_response(db, scope: str, key: str):
    row = db.query(IdempotencyKeyModel).filter(
        IdempotencyKeyModel.scope == scope,
        IdempotencyKeyModel.idempotency_key == key,
    ).first()
    return None if not row else row.response_json


def store_idempotent_response(db, scope: str, key: str, response_json: dict):
    row = IdempotencyKeyModel(
        id=str(uuid.uuid4()),
        scope=scope,
        idempotency_key=key,
        response_json=response_json,
    )
    db.add(row)
