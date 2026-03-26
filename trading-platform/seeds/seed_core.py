import uuid
from passlib.context import CryptContext
import psycopg

pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")


def insert_if_missing(cur, table, unique_col, unique_val, data):
    cur.execute(f"SELECT 1 FROM {table} WHERE {unique_col} = %s", (unique_val,))
    if cur.fetchone():
        return
    cols = ", ".join(data.keys())
    placeholders = ", ".join(["%s"] * len(data))
    cur.execute(f"INSERT INTO {table} ({cols}) VALUES ({placeholders})", tuple(data.values()))


conn = psycopg.connect("host=localhost port=5432 dbname=trading_platform user=postgres password=postgres")
with conn:
    with conn.cursor() as cur:
        for code, name in [
            ("super_admin", "Super Admin"),
            ("platform_admin", "Platform Admin"),
            ("quant_researcher", "Quant Researcher"),
            ("strategy_developer", "Strategy Developer"),
            ("operations", "Operations"),
            ("risk_officer", "Risk Officer"),
            ("compliance_officer", "Compliance Officer"),
            ("executive_viewer", "Executive Viewer"),
        ]:
            insert_if_missing(cur, "roles", "code", code, {"id": str(uuid.uuid4()), "code": code, "name": name})
        for code, name in [
            ("users.read", "Read users"),
            ("users.write", "Write users"),
            ("markets.read", "Read markets"),
            ("markets.write", "Write markets"),
            ("strategies.read", "Read strategies"),
            ("strategies.write", "Write strategies"),
            ("orders.read", "Read orders"),
            ("audit.read", "Read audit"),
        ]:
            insert_if_missing(cur, "permissions", "code", code, {"id": str(uuid.uuid4()), "code": code, "name": name})
        admin_email = "admin@example.com"
        insert_if_missing(cur, "users", "email", admin_email, {
            "id": str(uuid.uuid4()), "name": "Admin User", "email": admin_email,
            "password_hash": pwd.hash("admin123"), "status": "active", "mfa_enabled": False,
        })
        cur.execute("SELECT id FROM roles WHERE code = 'super_admin'")
        role_id = cur.fetchone()[0]
        cur.execute("SELECT id FROM users WHERE email = %s", (admin_email,))
        admin_id = cur.fetchone()[0]
        cur.execute("SELECT 1 FROM user_roles WHERE user_id = %s AND role_id = %s", (admin_id, role_id))
        if not cur.fetchone():
            cur.execute("INSERT INTO user_roles (user_id, role_id) VALUES (%s, %s)", (admin_id, role_id))
        insert_if_missing(cur, "markets", "code", "forex", {"id": str(uuid.uuid4()), "code": "forex", "name": "Forex", "asset_class": "forex", "timezone": "UTC", "status": "active"})
        insert_if_missing(cur, "markets", "code", "crypto", {"id": str(uuid.uuid4()), "code": "crypto", "name": "Crypto", "asset_class": "crypto", "timezone": "UTC", "status": "active"})
        cur.execute("SELECT id FROM markets WHERE code='forex'")
        forex_market_id = cur.fetchone()[0]
        cur.execute("SELECT id FROM markets WHERE code='crypto'")
        crypto_market_id = cur.fetchone()[0]
        insert_if_missing(cur, "venues", "code", "oanda-demo", {"id": str(uuid.uuid4()), "market_id": forex_market_id, "code": "oanda-demo", "name": "OANDA Demo", "venue_type": "broker", "status": "active"})
        insert_if_missing(cur, "venues", "code", "binance-testnet", {"id": str(uuid.uuid4()), "market_id": crypto_market_id, "code": "binance-testnet", "name": "Binance Testnet", "venue_type": "exchange", "status": "active"})
        cur.execute("SELECT id FROM venues WHERE code='oanda-demo'")
        oanda_venue_id = cur.fetchone()[0]
        for symbol, base_asset, quote_asset, tick, lot, pp, qp in [
            ("EURUSD", "EUR", "USD", "0.0001", "1000", 5, 2),
            ("GBPUSD", "GBP", "USD", "0.0001", "1000", 5, 2),
            ("USDJPY", "USD", "JPY", "0.01", "1000", 3, 2),
            ("XAUUSD", "XAU", "USD", "0.01", "1", 2, 2),
        ]:
            insert_if_missing(cur, "instruments", "canonical_symbol", symbol, {
                "id": str(uuid.uuid4()), "venue_id": oanda_venue_id, "canonical_symbol": symbol, "external_symbol": symbol,
                "asset_class": "forex", "base_asset": base_asset, "quote_asset": quote_asset,
                "tick_size": tick, "lot_size": lot, "price_precision": pp, "quantity_precision": qp,
                "contract_multiplier": None, "status": "active",
            })
        insert_if_missing(cur, "strategies", "code", "fx_ma_cross", {"id": str(uuid.uuid4()), "code": "fx_ma_cross", "name": "FX Moving Average Cross", "type": "trend_following", "owner_user_id": admin_id, "description": "Demo strategy", "status": "draft"})
        insert_if_missing(cur, "strategies", "code", "fx_mean_rev", {"id": str(uuid.uuid4()), "code": "fx_mean_rev", "name": "FX Mean Reversion", "type": "mean_reversion", "owner_user_id": admin_id, "description": "Demo strategy", "status": "draft"})
print("Seed complete.")
