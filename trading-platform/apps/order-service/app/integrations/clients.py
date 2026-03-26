import httpx
from app.config import settings


def internal_headers(correlation_id: str) -> dict:
    return {
        "X-Service-Name": "order-service",
        "X-Service-Token": settings.internal_service_token,
        "X-Correlation-ID": correlation_id,
    }


async def call_risk_service(payload: dict, correlation_id: str) -> dict:
    async with httpx.AsyncClient(timeout=10.0) as client:
        response = await client.post(
            f"{settings.risk_service_url}/api/risk/evaluate",
            json=payload,
            headers=internal_headers(correlation_id),
        )
        response.raise_for_status()
        return response.json()


async def call_execution_service(payload: dict, correlation_id: str) -> dict:
    async with httpx.AsyncClient(timeout=15.0) as client:
        response = await client.post(
            f"{settings.execution_service_url}/api/execution/simulate",
            json=payload,
            headers=internal_headers(correlation_id),
        )
        response.raise_for_status()
        return response.json()


async def call_position_service(payload: dict, correlation_id: str) -> dict:
    async with httpx.AsyncClient(timeout=10.0) as client:
        response = await client.post(
            f"{settings.position_service_url}/api/positions/apply-fill",
            json=payload,
            headers=internal_headers(correlation_id),
        )
        response.raise_for_status()
        return response.json()


async def call_audit_service(payload: dict, correlation_id: str) -> dict:
    async with httpx.AsyncClient(timeout=10.0) as client:
        response = await client.post(
            f"{settings.audit_service_url}/api/audit",
            json=payload,
            headers=internal_headers(correlation_id),
        )
        response.raise_for_status()
        return response.json()
