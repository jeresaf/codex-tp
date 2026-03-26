from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, EmailStr
from passlib.context import CryptContext
from sqlalchemy.orm import Session
from app.db.models import User
from app.db.session import get_db
from app.config import settings
from shared_auth.jwt_tools import create_access_token

router = APIRouter()
pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

@router.post("/login")
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == payload.email).first()
    if not user or not pwd.verify(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    user_data = {"id": user.id, "email": user.email, "roles": ["super_admin"], "permissions": ["users.read", "markets.read", "strategies.read", "orders.read", "audit.read"]}
    token = create_access_token(settings.jwt_secret, settings.jwt_algorithm, user_data)
    return {"access_token": token, "token_type": "bearer", "user": {"id": user.id, "name": user.name, "email": user.email, "status": user.status}, "roles": user_data["roles"], "permissions": user_data["permissions"]}
