import uuid
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from app.db.models import StrategyRuntimeHeartbeatModel, OutboxEventModel
from app.domain.sample_strategy import MovingAverageCrossSampleStrategy
from shared_events.outbox import append_outbox_event


def emit_heartbeat(db: Session, strategy_deployment_id: str, strategy_version_id: str | None, worker_id: str, correlation_id: str | None, status: str = "healthy"):
    row = StrategyRuntimeHeartbeatModel(
        id=str(uuid.uuid4()),
        strategy_deployment_id=strategy_deployment_id,
        strategy_version_id=strategy_version_id,
        worker_id=worker_id,
        status=status,
        last_processed_event_at=datetime.now(timezone.utc),
        correlation_id=correlation_id,
    )
    db.add(row)
    db.commit()
    return row


def run_sample_strategy_once(db: Session, candle: dict, strategy_deployment_id: str, strategy_version_id: str | None, correlation_id: str | None):
    worker_id = str(uuid.uuid4())
    emit_heartbeat(db, strategy_deployment_id, strategy_version_id, worker_id, correlation_id, status="healthy")
    strategy = MovingAverageCrossSampleStrategy()
    signals = strategy.on_candle(candle, {
        "strategy_deployment_id": strategy_deployment_id,
        "strategy_version_id": strategy_version_id,
    })
    for signal in signals:
        append_outbox_event(
            db=db,
            model_cls=OutboxEventModel,
            aggregate_type="strategy_signal",
            aggregate_id=signal.signal_id,
            event_type="strategy.signal.generated",
            event_version=1,
            correlation_id=correlation_id,
            causation_id=None,
            payload_json={
                "signal_id": signal.signal_id,
                "strategy_deployment_id": signal.strategy_deployment_id,
                "strategy_version_id": signal.strategy_version_id,
                "instrument_id": signal.instrument_id,
                "timestamp": signal.timestamp,
                "signal_type": signal.signal_type,
                "direction": signal.direction,
                "strength": signal.strength,
                "confidence": signal.confidence,
                "time_horizon": signal.time_horizon,
                "reason_codes": signal.reason_codes,
                "metadata": signal.metadata,
            },
        )
    db.commit()
    return {"signals_emitted": len(signals), "worker_id": worker_id}
