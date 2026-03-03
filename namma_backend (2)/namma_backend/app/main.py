import asyncio
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from app.database import init_db, seed_db
from app.routers import traffic, metro, reports, sos, ai
from app.services.realtime import ai_sync_loop

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Init DB and seed data
    init_db()
    seed_db()
    # Start AI real-time sync background task
    task = asyncio.create_task(ai_sync_loop())
    print("✅ AI real-time sync started (every 30s)")
    yield
    # Shutdown
    task.cancel()
    try:
        await task
    except asyncio.CancelledError:
        pass
    print("🛑 AI sync stopped")

app = FastAPI(
    title="Namma Commute API",
    description="""
## Namma Commute — Bengaluru Traffic Intelligence API

### 🤖 AI-Powered Features
- **Real-time congestion prediction** using weather + time patterns
- **Metro delay detection** via anomaly scoring
- **Smart route recommendations** comparing road vs metro vs bus
- **30-second refresh cycle** synced with OpenWeatherMap

### 📡 Key Endpoints
- `GET /api/v1/ai/live` — Full real-time dashboard (use this in Flutter)
- `GET /api/v1/ai/traffic/hotspots` — AI-ranked hotspots
- `GET /api/v1/ai/metro/status` — Live metro delay status
- `GET /api/v1/ai/routes/recommend` — Smart route recommendation

### 🌤️ Weather Integration
Set `OPENWEATHER_API_KEY` environment variable for live weather data.
Falls back to realistic Bengaluru defaults if not set.
    """,
    version="2.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Routers
app.include_router(ai.router,      prefix="/api/v1/ai",      tags=["🤖 AI Real-Time"])
app.include_router(traffic.router, prefix="/api/v1/traffic",  tags=["Traffic Incidents"])
app.include_router(metro.router,   prefix="/api/v1/metro",    tags=["Metro Schedule"])
app.include_router(reports.router, prefix="/api/v1/reports",  tags=["Incident Reports"])
app.include_router(sos.router,     prefix="/api/v1/sos",      tags=["SOS & Emergency"])

@app.get("/", tags=["Health"])
def root():
    return {
        "app":     "Namma Commute API",
        "version": "2.0.0",
        "status":  "running",
        "city":    "Bengaluru",
        "ai":      "active — refreshing every 30s",
        "docs":    "/docs",
    }

@app.get("/health", tags=["Health"])
def health():
    from app.services.realtime import get_live_store
    store = get_live_store()
    return {
        "status":    "healthy",
        "ai_sync":   store["sync"]["status"],
        "cycles":    store["sync"]["cycle_count"],
        "last_sync": store["sync"]["last_sync"],
    }
