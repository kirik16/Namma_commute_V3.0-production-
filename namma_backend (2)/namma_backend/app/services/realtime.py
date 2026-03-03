"""
Real-time AI sync service.
Runs a background task every 30 seconds that:
1. Fetches latest weather from OpenWeatherMap
2. Runs AI congestion prediction for all junctions
3. Runs metro delay detection
4. Stores results in the in-memory live store
5. Persists snapshot to SQLite for history
"""
import asyncio
import time
from datetime import datetime

from app.services.weather import get_weather, get_weather_summary
from app.ai.engine import (
    predict_all_junctions,
    get_city_traffic_index,
    detect_metro_delays,
)
from app.database import get_connection

REFRESH_INTERVAL_SEC = 30

# ── In-memory live store (shared across all requests) ──────────
_live_store = {
    "traffic": {
        "junctions":    [],
        "city_index":   {},
        "updated_at":   None,
    },
    "metro": {
        "lines":        [],
        "updated_at":   None,
    },
    "weather": {
        "current":      {},
        "summary":      "",
        "updated_at":   None,
    },
    "sync": {
        "cycle_count":  0,
        "last_sync":    None,
        "status":       "starting",
        "errors":       [],
    }
}

def get_live_store() -> dict:
    return _live_store

def _run_ai_cycle():
    """
    Single sync cycle: weather → AI predictions → store.
    Called every 30 seconds by the background loop.
    """
    cycle_start = time.time()
    now_iso     = datetime.now().isoformat()
    errors      = []

    try:
        # 1. Fetch weather (cached for 10 min internally)
        weather = get_weather()
        _live_store["weather"]["current"]    = weather
        _live_store["weather"]["summary"]    = get_weather_summary(weather)
        _live_store["weather"]["updated_at"] = now_iso

        # 2. AI: predict congestion for all junctions
        junction_preds = predict_all_junctions(weather)
        city_index     = get_city_traffic_index(junction_preds)

        _live_store["traffic"]["junctions"]  = junction_preds
        _live_store["traffic"]["city_index"] = city_index
        _live_store["traffic"]["updated_at"] = now_iso

        # 3. AI: detect metro delays
        metro_status = detect_metro_delays(weather)
        _live_store["metro"]["lines"]        = metro_status
        _live_store["metro"]["updated_at"]   = now_iso

        # 4. Persist snapshot to DB
        _persist_snapshot(city_index, junction_preds, metro_status, weather, now_iso)

    except Exception as e:
        errors.append(f"{now_iso}: {str(e)}")

    # 5. Update sync metadata
    elapsed = round(time.time() - cycle_start, 3)
    _live_store["sync"]["cycle_count"] += 1
    _live_store["sync"]["last_sync"]    = now_iso
    _live_store["sync"]["status"]       = "running" if not errors else "degraded"
    _live_store["sync"]["last_duration_sec"] = elapsed
    # Keep last 10 errors
    if errors:
        _live_store["sync"]["errors"] = (errors + _live_store["sync"]["errors"])[:10]

    print(f"[AI Sync #{_live_store['sync']['cycle_count']}] "
          f"City index: {_live_store['traffic']['city_index'].get('index', '?')} "
          f"| Weather: {_live_store['weather']['summary']} "
          f"| {elapsed}s")

def _persist_snapshot(city_index, junctions, metro, weather, ts):
    """Save a lightweight snapshot to SQLite for trend history."""
    try:
        conn = get_connection()
        conn.execute("""
            CREATE TABLE IF NOT EXISTS ai_snapshots (
                id           INTEGER PRIMARY KEY AUTOINCREMENT,
                ts           TEXT NOT NULL,
                city_index   INTEGER,
                label        TEXT,
                critical_cnt INTEGER,
                weather_main TEXT,
                temp_c       REAL,
                rain_1h      REAL,
                metro_status TEXT
            )
        """)
        metro_summary = ",".join(
            f"{m['line_name']}:{m['status']}" for m in metro
        )
        conn.execute("""
            INSERT INTO ai_snapshots
                (ts, city_index, label, critical_cnt, weather_main, temp_c, rain_1h, metro_status)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            ts,
            city_index.get("index"),
            city_index.get("label"),
            city_index.get("critical_count"),
            weather.get("main"),
            weather.get("temp"),
            weather.get("rain_1h", 0),
            metro_summary,
        ))
        conn.commit()
        # Keep only last 2880 snapshots (24h × 2/min)
        conn.execute("""
            DELETE FROM ai_snapshots
            WHERE id NOT IN (
                SELECT id FROM ai_snapshots ORDER BY id DESC LIMIT 2880
            )
        """)
        conn.commit()
        conn.close()
    except Exception as e:
        print(f"[AI Sync] DB persist error: {e}")

async def ai_sync_loop():
    """
    Async background task. Run once immediately then every 30 seconds.
    """
    print("🤖 AI Sync engine starting...")
    _live_store["sync"]["status"] = "running"

    while True:
        try:
            # Run sync in executor so it doesn't block the event loop
            loop = asyncio.get_event_loop()
            await loop.run_in_executor(None, _run_ai_cycle)
        except Exception as e:
            print(f"[AI Sync] Loop error: {e}")
            _live_store["sync"]["status"] = "error"

        await asyncio.sleep(REFRESH_INTERVAL_SEC)
