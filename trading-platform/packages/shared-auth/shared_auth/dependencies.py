from fastapi import Header, HTTPException
import jwt

JWT_ISSUER = "trading-platform"


def get_bearer_token(authorization: str | None = Header(default=None)) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")
    return authorization.replace("Bearer ", "", 1)


def decode_token(token: str, secret: str, algorithm: str) -> dict:
    try:
        return jwt.decode(token, secret, algorithms=[algorithm], issuer=JWT_ISSUER)
    except Exception as exc:
        raise HTTPException(status_code=401, detail=f"Invalid token: {exc}")


def require_user_context(secret: str, algorithm: str):
    def _dep(authorization: str | None = Header(default=None)) -> dict:
        token = get_bearer_token(authorization)
        return decode_token(token, secret, algorithm)
    return _dep


def validate_internal_service(expected_token: str):
    def _dep(
        x_service_name: str | None = Header(default=None),
        x_service_token: str | None = Header(default=None),
    ) -> dict:
        if not x_service_name or not x_service_token:
            raise HTTPException(status_code=401, detail="Missing internal auth headers")
        if x_service_token != expected_token:
            raise HTTPException(status_code=401, detail="Invalid internal service token")
        return {"service_name": x_service_name}
    return _dep
