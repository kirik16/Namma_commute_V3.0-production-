from fastapi import APIRouter, HTTPException, Query
from typing import List, Optional
from datetime import datetime

from app.database import get_connection
from app.schemas.schemas import MetroLine, MetroStation, MetroScheduleItem

router = APIRouter()

@router.get("/lines", response_model=List[MetroLine], summary="Get all metro lines")
def get_lines():
    conn = get_connection()
    rows = conn.execute("SELECT * FROM metro_lines").fetchall()
    conn.close()
    return [dict(r) for r in rows]

@router.get("/lines/{line_id}", response_model=MetroLine, summary="Get metro line details")
def get_line(line_id: int):
    conn = get_connection()
    row = conn.execute("SELECT * FROM metro_lines WHERE id = ?", (line_id,)).fetchone()
    conn.close()
    if not row:
        raise HTTPException(status_code=404, detail="Line not found")
    return dict(row)

@router.get("/lines/{line_id}/stations", response_model=List[MetroStation], summary="Get all stations on a line")
def get_stations(line_id: int):
    conn = get_connection()
    line = conn.execute("SELECT * FROM metro_lines WHERE id = ?", (line_id,)).fetchone()
    if not line:
        conn.close()
        raise HTTPException(status_code=404, detail="Line not found")
    rows = conn.execute(
        "SELECT * FROM metro_stations WHERE line_id = ? ORDER BY sequence", (line_id,)
    ).fetchall()
    conn.close()
    return [
        {**dict(r), "is_hub": bool(r["is_hub"])}
        for r in rows
    ]

@router.get("/lines/{line_id}/schedule", response_model=List[MetroScheduleItem], summary="Get upcoming trains for a line")
def get_schedule(
    line_id: int,
    from_station: Optional[str] = Query(None, description="Filter by departure station"),
):
    conn = get_connection()
    line = conn.execute("SELECT * FROM metro_lines WHERE id = ?", (line_id,)).fetchone()
    if not line:
        conn.close()
        raise HTTPException(status_code=404, detail="Line not found")

    if from_station:
        rows = conn.execute(
            "SELECT * FROM metro_schedule WHERE line_id = ? AND from_station = ?",
            (line_id, from_station)
        ).fetchall()
    else:
        rows = conn.execute(
            "SELECT * FROM metro_schedule WHERE line_id = ?", (line_id,)
        ).fetchall()
    conn.close()
    return [dict(r) for r in rows]

@router.get("/hubs", summary="Get all interchange hub stations")
def get_hubs():
    conn = get_connection()
    rows = conn.execute("""
        SELECT s.name, s.latitude, s.longitude, l.name as line_name, l.color
        FROM metro_stations s
        JOIN metro_lines l ON s.line_id = l.id
        WHERE s.is_hub = 1
        ORDER BY s.name
    """).fetchall()
    conn.close()

    # Group by station name
    hubs = {}
    for r in rows:
        name = r["name"]
        if name not in hubs:
            hubs[name] = {"name": name, "latitude": r["latitude"], "longitude": r["longitude"], "lines": []}
        hubs[name]["lines"].append({"line": r["line_name"], "color": r["color"]})

    return {"hubs": list(hubs.values())}

@router.get("/status", summary="Get live metro service status")
def get_status():
    return {
        "updated_at": datetime.now().isoformat(),
        "lines": [
            {
                "name": "Purple Line",
                "color": "#7B2D8B",
                "status": "normal",
                "message": "Services running normally",
                "frequency": "Every 6 minutes",
                "first_train": "05:30 AM",
                "last_train": "11:30 PM",
            },
            {
                "name": "Green Line",
                "color": "#1D8348",
                "status": "normal",
                "message": "Services running normally",
                "frequency": "Every 8 minutes",
                "first_train": "05:45 AM",
                "last_train": "11:15 PM",
            }
        ]
    }

@router.get("/fare", summary="Calculate metro fare")
def calculate_fare(
    from_station: str = Query(...),
    to_station: str = Query(...),
    line_id: int = Query(...)
):
    conn = get_connection()
    from_row = conn.execute(
        "SELECT sequence FROM metro_stations WHERE line_id = ? AND name = ?", (line_id, from_station)
    ).fetchone()
    to_row = conn.execute(
        "SELECT sequence FROM metro_stations WHERE line_id = ? AND name = ?", (line_id, to_station)
    ).fetchone()
    conn.close()

    if not from_row or not to_row:
        raise HTTPException(status_code=404, detail="Station not found on specified line")

    stops = abs(to_row["sequence"] - from_row["sequence"])

    # Namma Metro fare slab (approximate)
    if stops <= 2:
        fare = 10
    elif stops <= 5:
        fare = 20
    elif stops <= 9:
        fare = 30
    elif stops <= 14:
        fare = 40
    else:
        fare = 50

    return {
        "from_station": from_station,
        "to_station": to_station,
        "stops": stops,
        "fare_inr": fare,
        "note": "Approximate fare. Check Namma Metro app for exact fare."
    }
