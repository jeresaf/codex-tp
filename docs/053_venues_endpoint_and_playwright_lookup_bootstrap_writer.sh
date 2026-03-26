#!/usr/bin/env bash
set -euo pipefail

# Adds a proper venues API and updates Playwright to auto-resolve oanda-demo.
# Run inside the existing trading-platform repo root.

ROOT="$(pwd)"
if [ ! -f "$ROOT/docker-compose.yml" ]; then
  echo "Run this inside the trading-platform repo root."
  exit 1
fi

mkdir -p \
  apps/market-registry-service/app/api/routes \
  apps/market-registry-service/app/db \
  tests/e2e/fixtures

cat > apps/market-registry-service/app/db/models.py <<'EOF'
from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column
from shared_db.database import Base


class Market(Base):
    __tablename__ = "markets"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    code: Mapped[str] = mapped_column(String(50), unique=True, nullable=False)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    asset_class: Mapped[str] = mapped_column(String(50), nullable=False)
    timezone: Mapped[str] = mapped_column(String(100), nullable=False)
    status: Mapped[str] = mapped_column(String(50), nullable=False, default="active")


class Venue(Base):
    __tablename__ = "venues"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    market_id: Mapped[str] = mapped_column(String, nullable=False)
    code: Mapped[str] = mapped_column(String(50), unique=True, nullable=False)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    venue_type: Mapped[str] = mapped_column(String(50), nullable=False)
    status: Mapped[str] = mapped_column(String(50), nullable=False, default="active")
EOF

cat > apps/market-registry-service/app/api/routes/markets.py <<'EOF'
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import Market

router = APIRouter()


@router.get("/")
def list_markets(db: Session = Depends(get_db)):
    rows = db.query(Market).order_by(Market.code.asc()).all()
    return [
        {
            "id": x.id,
            "code": x.code,
            "name": x.name,
            "asset_class": x.asset_class,
            "timezone": x.timezone,
            "status": x.status,
        }
        for x in rows
    ]
EOF

cat > apps/market-registry-service/app/api/routes/venues.py <<'EOF'
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.db.models import Venue

router = APIRouter()


@router.get("/")
def list_venues(
    code: str | None = Query(default=None),
    market_id: str | None = Query(default=None),
    db: Session = Depends(get_db),
):
    query = db.query(Venue)
    if code:
        query = query.filter(Venue.code == code)
    if market_id:
        query = query.filter(Venue.market_id == market_id)
    rows = query.order_by(Venue.code.asc()).all()
    return [
        {
            "id": x.id,
            "market_id": x.market_id,
            "code": x.code,
            "name": x.name,
            "venue_type": x.venue_type,
            "status": x.status,
        }
        for x in rows
    ]
EOF

cat > apps/market-registry-service/app/main.py <<'EOF'
from fastapi import FastAPI
from app.api.routes.markets import router as markets_router
from app.api.routes.venues import router as venues_router

app = FastAPI(title="market-registry-service", version="0.2.0")
app.include_router(markets_router, prefix="/api/markets", tags=["markets"])
app.include_router(venues_router, prefix="/api/venues", tags=["venues"])


@app.get("/health/live")
def health_live():
    return {"status": "ok", "service": "market-registry-service"}


@app.get("/health/ready")
def health_ready():
    return {"status": "ready", "service": "market-registry-service"}
EOF

cat > tests/e2e/fixtures/ids.ts <<'EOF'
import { APIRequestContext, expect } from "@playwright/test"

export async function getAdminToken(request: APIRequestContext) {
  const login = await request.post("http://localhost:8001/api/auth/login", {
    data: { email: "admin@example.com", password: "admin" }
  })
  expect(login.ok()).toBeTruthy()
  const auth = await login.json()
  return auth.access_token as string
}

export async function getSeededInstrumentId(request: APIRequestContext, symbol = "EURUSD") {
  const token = await getAdminToken(request)
  const response = await request.get("http://localhost:8003/api/instruments", {
    headers: { Authorization: `Bearer ${token}` }
  })
  expect(response.ok()).toBeTruthy()
  const rows = await response.json()
  const found = rows.find((x: any) => x.canonical_symbol === symbol)
  expect(found).toBeTruthy()
  return found.id as string
}

export async function getSeededVenueId(request: APIRequestContext, code = "oanda-demo") {
  const token = await getAdminToken(request)
  const response = await request.get(`http://localhost:8002/api/venues?code=${encodeURIComponent(code)}`, {
    headers: { Authorization: `Bearer ${token}` }
  })
  expect(response.ok()).toBeTruthy()
  const rows = await response.json()
  const found = rows.find((x: any) => x.code === code)
  expect(found).toBeTruthy()
  return found.id as string
}
EOF

cat > tests/e2e/ops/orders.spec.ts <<'EOF'
import { test, expect } from "@playwright/test"
import { loginUi } from "../fixtures/auth"
import { getSeededInstrumentId, getSeededVenueId } from "../fixtures/ids"

test("ops can open orders page and submit order", async ({ page, request }) => {
  const instrumentId = await getSeededInstrumentId(request)
  const venueId = await getSeededVenueId(request)

  await loginUi(page, "http://localhost:3001", "admin@example.com", "admin", "Ops Login")
  await page.goto("http://localhost:3001/orders")

  await page.getByPlaceholder("Instrument ID").fill(instrumentId)
  await page.getByPlaceholder("Venue ID").fill(venueId)
  await page.getByPlaceholder("Quantity").fill("1000")
  await page.getByPlaceholder("Execution Price").fill("1.0850")
  await page.getByRole("button", { name: "Submit Order" }).click()

  await expect(page.locator("pre")).toBeVisible()
})
EOF

python - <<'PY'
from pathlib import Path
p = Path('.github/workflows/e2e.yml')
if p.exists():
    text = p.read_text()
    text = text.replace('''      - name: Set seeded venue id
        run: echo "PLAYWRIGHT_VENUE_ID=${{ secrets.PLAYWRIGHT_VENUE_ID }}" >> $GITHUB_ENV

''', '')
    p.write_text(text)
PY

echo "Venues endpoint and Playwright lookup applied."
echo "Next: docker-compose build market-registry-service web-ops && docker-compose up -d market-registry-service web-ops"
echo "Then run: cd tests && npm install && npx playwright install --with-deps && npm test"
