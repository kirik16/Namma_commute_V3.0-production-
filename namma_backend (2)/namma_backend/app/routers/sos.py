from fastapi import APIRouter, HTTPException, Query
from typing import List, Optional
from datetime import datetime

from app.database import get_connection
from app.schemas.schemas import SOSAlert, SOSAlertCreate, EmergencyContact

router = APIRouter()

def row_to_alert(row) -> dict:
    return {
        "id": row["id"],
        "user_id": row["user_id"],
        "latitude": row["latitude"],
        "longitude": row["longitude"],
        "location_text": row["location_text"],
        "alert_type": row["alert_type"],
        "message": row["message"],
        "created_at": row["created_at"],
        "status": row["status"],
        "contact_name": row["contact_name"],
        "contact_phone": row["contact_phone"],
    }

@router.post("/alert", response_model=SOSAlert, status_code=201, summary="🆘 Trigger SOS emergency alert")
def trigger_sos(data: SOSAlertCreate):
    """
    Triggers an SOS emergency alert. In production this would:
    - Send SMS to emergency contacts
    - Notify nearest police/ambulance
    - Share location with BBMP control room
    """
    conn = get_connection()
    cur = conn.cursor()
    now = datetime.now().isoformat()

    cur.execute("""
        INSERT INTO sos_alerts
            (user_id, latitude, longitude, location_text, alert_type, message, created_at, contact_name, contact_phone)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        data.user_id, data.latitude, data.longitude,
        data.location_text, data.alert_type, data.message,
        now, data.contact_name, data.contact_phone
    ))
    conn.commit()
    alert_id = cur.lastrowid
    row = conn.execute("SELECT * FROM sos_alerts WHERE id = ?", (alert_id,)).fetchone()
    conn.close()

    alert = row_to_alert(row)
    # In production: trigger SMS/notification here
    print(f"🚨 SOS ALERT #{alert_id} triggered at {data.latitude},{data.longitude} — Type: {data.alert_type}")
    return alert

@router.get("/alerts", response_model=List[SOSAlert], summary="Get all SOS alerts (admin)")
def get_alerts(
    status: Optional[str] = Query("active", description="Filter: active, responded, resolved"),
    limit: int = Query(20, le=100),
):
    conn = get_connection()
    query = "SELECT * FROM sos_alerts WHERE 1=1"
    params = []
    if status:
        query += " AND status = ?"
        params.append(status)
    query += " ORDER BY created_at DESC LIMIT ?"
    params.append(limit)
    rows = conn.execute(query, params).fetchall()
    conn.close()
    return [row_to_alert(r) for r in rows]

@router.get("/alerts/{alert_id}", response_model=SOSAlert, summary="Get a specific SOS alert")
def get_alert(alert_id: int):
    conn = get_connection()
    row = conn.execute("SELECT * FROM sos_alerts WHERE id = ?", (alert_id,)).fetchone()
    conn.close()
    if not row:
        raise HTTPException(status_code=404, detail="Alert not found")
    return row_to_alert(row)

@router.patch("/alerts/{alert_id}/status", summary="Update SOS alert status")
def update_alert_status(
    alert_id: int,
    status: str = Query(..., pattern="^(active|responded|resolved)$")
):
    conn = get_connection()
    row = conn.execute("SELECT * FROM sos_alerts WHERE id = ?", (alert_id,)).fetchone()
    if not row:
        conn.close()
        raise HTTPException(status_code=404, detail="Alert not found")
    conn.execute("UPDATE sos_alerts SET status = ? WHERE id = ?", (status, alert_id))
    conn.commit()
    conn.close()
    return {"id": alert_id, "status": status, "message": f"Alert status updated to {status}"}

@router.get("/contacts", response_model=List[EmergencyContact], summary="Get all emergency contacts")
def get_emergency_contacts(
    type: Optional[str] = Query(None, description="Filter: police, ambulance, fire, bbmp, metro, bmtc"),
):
    conn = get_connection()
    if type:
        rows = conn.execute(
            "SELECT * FROM emergency_contacts WHERE type = ?", (type,)
        ).fetchall()
    else:
        rows = conn.execute("SELECT * FROM emergency_contacts").fetchall()
    conn.close()
    return [dict(r) for r in rows]

@router.get("/guidance", summary="Get accident response guidance steps")
def get_guidance():
    return {
        "steps": [
            {"step": 1, "title": "Stay Calm",          "desc": "Take a deep breath. Assess yourself for injuries before moving."},
            {"step": 2, "title": "Call Emergency",     "desc": "Call 108 for ambulance or 103 for Traffic Police immediately."},
            {"step": 3, "title": "Share Location",     "desc": "Use this SOS button to share your exact GPS location with emergency services."},
            {"step": 4, "title": "Don't Move Vehicle", "desc": "Unless it's unsafe, keep vehicles in place until police arrive."},
            {"step": 5, "title": "Document the Scene", "desc": "Take photos of damage, number plates, and road conditions if safe."},
        ],
        "emergency_numbers": {
            "ambulance": "108",
            "traffic_police": "103",
            "fire": "101",
            "bbmp": "1533",
            "women_helpline": "1091",
        }
    }
