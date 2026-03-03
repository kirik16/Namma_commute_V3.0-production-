from fastapi import APIRouter, HTTPException, Query
from typing import List, Optional
from datetime import datetime

from app.database import get_connection
from app.schemas.schemas import TrafficIncident, TrafficIncidentCreate, UpvoteResponse

router = APIRouter()

def row_to_incident(row) -> dict:
    return {
        "id": row["id"],
        "title": row["title"],
        "location": row["location"],
        "latitude": row["latitude"],
        "longitude": row["longitude"],
        "type": row["type"],
        "severity": row["severity"],
        "description": row["description"],
        "reported_at": row["reported_at"],
        "is_active": bool(row["is_active"]),
        "upvotes": row["upvotes"],
        "source": row["source"],
    }

@router.get("/", response_model=List[TrafficIncident], summary="Get all active traffic incidents")
def get_incidents(
    severity: Optional[str] = Query(None, description="Filter by: critical, high, moderate, low"),
    type: Optional[str] = Query(None, description="Filter by: accident, construction, flood, event, signal, pothole"),
    limit: int = Query(20, le=100),
):
    conn = get_connection()
    cur = conn.cursor()

    query = "SELECT * FROM traffic_incidents WHERE is_active = 1"
    params = []

    if severity:
        query += " AND severity = ?"
        params.append(severity)
    if type:
        query += " AND type = ?"
        params.append(type)

    query += " ORDER BY CASE severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'moderate' THEN 3 ELSE 4 END, reported_at DESC LIMIT ?"
    params.append(limit)

    rows = cur.execute(query, params).fetchall()
    conn.close()
    return [row_to_incident(r) for r in rows]

@router.get("/summary", summary="Get city traffic summary")
def get_traffic_summary():
    conn = get_connection()
    cur = conn.cursor()

    total = cur.execute("SELECT COUNT(*) FROM traffic_incidents WHERE is_active = 1").fetchone()[0]
    critical = cur.execute("SELECT COUNT(*) FROM traffic_incidents WHERE is_active = 1 AND severity = 'critical'").fetchone()[0]
    by_type = cur.execute("""
        SELECT type, COUNT(*) as count FROM traffic_incidents
        WHERE is_active = 1 GROUP BY type
    """).fetchall()

    # Simple traffic index: more incidents = higher congestion score
    score = min(100, int((critical * 20) + (total * 3)))
    index = 100 - score  # Invert: lower = worse traffic

    conn.close()
    return {
        "city": "Bengaluru",
        "traffic_index": index,
        "total_active_incidents": total,
        "critical_incidents": critical,
        "incidents_by_type": {r["type"]: r["count"] for r in by_type},
        "updated_at": datetime.now().isoformat(),
    }

@router.get("/hotspots", summary="Get top traffic hotspots")
def get_hotspots():
    hotspots = [
        {"rank": 1, "name": "Silk Board Junction",     "delay_min": 45, "severity": "critical", "lat": 12.9166, "lng": 77.6224},
        {"rank": 2, "name": "Marathahalli Bridge",     "delay_min": 28, "severity": "high",     "lat": 12.9564, "lng": 77.7010},
        {"rank": 3, "name": "KR Puram Signal",         "delay_min": 32, "severity": "high",     "lat": 13.0041, "lng": 77.6963},
        {"rank": 4, "name": "Hebbal Flyover",          "delay_min": 15, "severity": "moderate", "lat": 13.0358, "lng": 77.5970},
        {"rank": 5, "name": "Tin Factory Junction",    "delay_min": 18, "severity": "moderate", "lat": 13.0000, "lng": 77.6600},
        {"rank": 6, "name": "Electronic City Toll",    "delay_min": 22, "severity": "high",     "lat": 12.8399, "lng": 77.6770},
        {"rank": 7, "name": "Sarjapur Road",           "delay_min": 20, "severity": "moderate", "lat": 12.9121, "lng": 77.7048},
        {"rank": 8, "name": "Bellary Road, Hebbal",    "delay_min": 12, "severity": "moderate", "lat": 13.0450, "lng": 77.5950},
    ]
    return {"hotspots": hotspots, "updated_at": datetime.now().isoformat()}

@router.get("/{incident_id}", response_model=TrafficIncident, summary="Get single incident by ID")
def get_incident(incident_id: int):
    conn = get_connection()
    row = conn.execute("SELECT * FROM traffic_incidents WHERE id = ?", (incident_id,)).fetchone()
    conn.close()
    if not row:
        raise HTTPException(status_code=404, detail=f"Incident {incident_id} not found")
    return row_to_incident(row)

@router.post("/", response_model=TrafficIncident, status_code=201, summary="Create a new traffic incident")
def create_incident(data: TrafficIncidentCreate):
    conn = get_connection()
    cur = conn.cursor()
    now = datetime.now().isoformat()
    cur.execute("""
        INSERT INTO traffic_incidents (title, location, latitude, longitude, type, severity, description, reported_at, source)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'user')
    """, (data.title, data.location, data.latitude, data.longitude, data.type, data.severity, data.description, now))
    conn.commit()
    row = conn.execute("SELECT * FROM traffic_incidents WHERE id = ?", (cur.lastrowid,)).fetchone()
    conn.close()
    return row_to_incident(row)

@router.post("/{incident_id}/upvote", response_model=UpvoteResponse, summary="Upvote an incident")
def upvote_incident(incident_id: int):
    conn = get_connection()
    row = conn.execute("SELECT * FROM traffic_incidents WHERE id = ?", (incident_id,)).fetchone()
    if not row:
        conn.close()
        raise HTTPException(status_code=404, detail="Incident not found")
    conn.execute("UPDATE traffic_incidents SET upvotes = upvotes + 1 WHERE id = ?", (incident_id,))
    conn.commit()
    new_count = conn.execute("SELECT upvotes FROM traffic_incidents WHERE id = ?", (incident_id,)).fetchone()[0]
    conn.close()
    return {"id": incident_id, "upvotes": new_count, "message": "Upvote recorded"}

@router.delete("/{incident_id}", summary="Mark incident as resolved")
def resolve_incident(incident_id: int):
    conn = get_connection()
    row = conn.execute("SELECT * FROM traffic_incidents WHERE id = ?", (incident_id,)).fetchone()
    if not row:
        conn.close()
        raise HTTPException(status_code=404, detail="Incident not found")
    conn.execute("UPDATE traffic_incidents SET is_active = 0 WHERE id = ?", (incident_id,))
    conn.commit()
    conn.close()
    return {"message": f"Incident {incident_id} marked as resolved"}
