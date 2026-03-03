from fastapi import APIRouter, Query
from typing import Optional
from datetime import datetime

from app.services.realtime import get_live_store
from app.services.weather import get_weather
from app.ai.engine import (
    predict_congestion,
    recommend_routes,
    detect_metro_delays,
    JUNCTION_BASE_CONGESTION,
    ROUTE_GRAPH,
)

router = APIRouter()

# ─────────────────────────────────────────
# LIVE DASHBOARD — single endpoint for app
# ─────────────────────────────────────────

@router.get("/live", summary="📡 Get full real-time AI dashboard data")
def get_live_dashboard():
    """
    Returns everything the Flutter app needs in one call:
    - City traffic index
    - All junction predictions
    - Metro delay status
    - Current weather
    - Sync metadata
    Refreshed every 30 seconds by background AI engine.
    """
    store = get_live_store()
    return {
        "city":     "Bengaluru",
        "traffic":  store["traffic"],
        "metro":    store["metro"],
        "weather":  store["weather"],
        "sync":     store["sync"],
        "fetched_at": datetime.now().isoformat(),
    }

# ─────────────────────────────────────────
# TRAFFIC CONGESTION
# ─────────────────────────────────────────

@router.get("/traffic/predict", summary="🚦 AI congestion prediction for all junctions")
def predict_traffic():
    store = get_live_store()
    return {
        "city_index":  store["traffic"]["city_index"],
        "junctions":   store["traffic"]["junctions"],
        "weather":     store["weather"]["summary"],
        "updated_at":  store["traffic"]["updated_at"],
    }

@router.get("/traffic/predict/{junction}", summary="🚦 Predict congestion for a specific junction")
def predict_single_junction(junction: str):
    weather = get_live_store()["weather"]["current"] or get_weather()
    if junction not in JUNCTION_BASE_CONGESTION:
        available = list(JUNCTION_BASE_CONGESTION.keys())
        return {"error": f"Junction not found. Available: {available}"}
    return predict_congestion(junction, weather)

@router.get("/traffic/hotspots", summary="🔥 AI-ranked live traffic hotspots")
def get_ai_hotspots(limit: int = Query(8, le=12)):
    store   = get_live_store()
    junctions = store["traffic"]["junctions"]
    if not junctions:
        weather   = get_weather()
        from app.ai.engine import predict_all_junctions
        junctions = predict_all_junctions(weather)

    hotspots = []
    for i, j in enumerate(junctions[:limit], 1):
        hotspots.append({
            "rank":      i,
            "name":      j["junction"],
            "score":     j["score"],
            "severity":  j["severity"],
            "color":     j["color"],
            "delay_min": j["delay_min"],
            "message":   j["message"],
        })
    return {
        "hotspots":   hotspots,
        "updated_at": store["traffic"]["updated_at"],
        "weather":    store["weather"]["summary"],
    }

# ─────────────────────────────────────────
# METRO DELAYS
# ─────────────────────────────────────────

@router.get("/metro/status", summary="🚇 AI-powered metro delay detection")
def get_metro_ai_status():
    store = get_live_store()
    lines = store["metro"]["lines"]
    if not lines:
        weather = get_weather()
        lines   = detect_metro_delays(weather)
    return {
        "lines":      lines,
        "updated_at": store["metro"]["updated_at"],
        "weather":    store["weather"]["summary"],
    }

# ─────────────────────────────────────────
# SMART ROUTE RECOMMENDATIONS
# ─────────────────────────────────────────

@router.get("/routes/recommend", summary="🗺️ AI smart route recommendation")
def get_route_recommendation(
    origin:      str = Query(..., description="e.g. Koramangala"),
    destination: str = Query(..., description="e.g. MG Road"),
):
    store       = get_live_store()
    weather     = store["weather"]["current"] or get_weather()
    predictions = store["traffic"]["junctions"]
    metro_status= store["metro"]["lines"]

    if not predictions:
        from app.ai.engine import predict_all_junctions
        predictions = predict_all_junctions(weather)
    if not metro_status:
        metro_status = detect_metro_delays(weather)

    result = recommend_routes(origin, destination, predictions, metro_status, weather)
    result["updated_at"] = store["traffic"]["updated_at"]
    return result

@router.get("/routes/available", summary="List all available origin-destination pairs")
def list_available_routes():
    pairs = []
    for (orig, dest) in ROUTE_GRAPH.keys():
        pairs.append({"origin": orig, "destination": dest})
        pairs.append({"origin": dest, "destination": orig})
    return {"routes": pairs, "total": len(pairs)}

# ─────────────────────────────────────────
# HISTORY & TRENDS
# ─────────────────────────────────────────

@router.get("/history", summary="📈 AI prediction history (last 1 hour)")
def get_history(limit: int = Query(120, le=500)):
    from app.database import get_connection
    try:
        conn = get_connection()
        rows = conn.execute("""
            SELECT ts, city_index, label, critical_cnt,
                   weather_main, temp_c, rain_1h, metro_status
            FROM ai_snapshots
            ORDER BY id DESC LIMIT ?
        """, (limit,)).fetchall()
        conn.close()
        return {
            "snapshots": [dict(r) for r in rows],
            "count":     len(rows),
        }
    except Exception as e:
        return {"error": str(e), "snapshots": []}

@router.get("/sync/status", summary="⚙️ AI sync engine status")
def get_sync_status():
    store = get_live_store()
    return {
        "status":       store["sync"]["status"],
        "cycle_count":  store["sync"]["cycle_count"],
        "last_sync":    store["sync"]["last_sync"],
        "refresh_every": "30 seconds",
        "errors":       store["sync"].get("errors", []),
        "last_duration_sec": store["sync"].get("last_duration_sec"),
    }
