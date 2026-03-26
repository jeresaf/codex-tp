from datetime import datetime, timedelta, timezone
import jwt

JWT_ISSUER = "trading-platform"
JWT_EXP_HOURS = 8


def create_access_token(secret: str, algorithm: str, user: dict) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": user["id"],
        "email": user["email"],
        "roles": user.get("roles", []),
        "permissions": user.get("permissions", []),
        "iss": JWT_ISSUER,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(hours=JWT_EXP_HOURS)).timestamp()),
    }
    return jwt.encode(payload, secret, algorithm=algorithm)
