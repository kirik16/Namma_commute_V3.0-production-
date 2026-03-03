from fastapi import APIRouter, HTTPException, Query
from typing import List, Optional
from datetime import datetime

from app.database import get_connection
from app.schemas.schemas import IncidentReport, IncidentReportCreate, UpvoteResponse

router = APIRouter()

def row_to_report(row) -> dict:
    return {
        "id": row["id"],
        "type": row["type"],
        "location": row["location"],
        "area": row["area"],
        "latitude": row["latitude"],
        "longitude": row["longitude"],
        "description": row["description"],
        "severity": row["severity"],
        "reporter_id": row["reporter_id"],
        "reported_at": row["reported_at"],
        "status": row["status"],
        "upvotes": row["upvotes"],
    }

@router.get("/", response_model=List[IncidentReport], summary="Get all citizen reports")
def get_reports(
    area: Optional[str] = Query(None, description="Filter by area e.g. Koramangala"),
    type: Optional[str] = Query(None, description="Filter by type: pothole, accident, etc."),
    status: Optional[str] = Query("open", description="Filter by status: open, in_review, resolved"),
    limit: int = Query(30, le=100),
):
    conn = get_connection()
    query = "SELECT * FROM incident_reports WHERE 1=1"
    params = []

    if area:
        query += " AND area LIKE ?"
        params.append(f"%{area}%")
    if type:
        query += " AND type = ?"
        params.append(type)
    if status:
        query += " AND status = ?"
        params.append(status)

    query += " ORDER BY upvotes DESC, reported_at DESC LIMIT ?"
    params.append(limit)

    rows = conn.execute(query, params).fetchall()
    conn.close()
    return [row_to_report(r) for r in rows]

@router.get("/stats", summary="Get reporting statistics by area and type")
def get_stats():
    conn = get_connection()
    by_area = conn.execute("""
        SELECT area, COUNT(*) as count FROM incident_reports
        WHERE status != 'resolved' GROUP BY area ORDER BY count DESC LIMIT 10
    """).fetchall()
    by_type = conn.execute("""
        SELECT type, COUNT(*) as count FROM incident_reports
        WHERE status != 'resolved' GROUP BY type ORDER BY count DESC
    """).fetchall()
    conn.close()
    return {
        "top_areas": [{"area": r["area"], "reports": r["count"]} for r in by_area],
        "by_type": {r["type"]: r["count"] for r in by_type},
        "updated_at": datetime.now().isoformat(),
    }

@router.get("/{report_id}", response_model=IncidentReport, summary="Get a single report")
def get_report(report_id: int):
    conn = get_connection()
    row = conn.execute("SELECT * FROM incident_reports WHERE id = ?", (report_id,)).fetchone()
    conn.close()
    if not row:
        raise HTTPException(status_code=404, detail="Report not found")
    return row_to_report(row)

@router.post("/", response_model=IncidentReport, status_code=201, summary="Submit a citizen incident report")
def create_report(data: IncidentReportCreate):
    conn = get_connection()
    cur = conn.cursor()
    now = datetime.now().isoformat()
    cur.execute("""
        INSERT INTO incident_reports
            (type, location, area, latitude, longitude, description, severity, reporter_id, reported_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        data.type, data.location, data.area,
        data.latitude, data.longitude,
        data.description, data.severity,
        data.reporter_id, now
    ))
    conn.commit()
    row = conn.execute("SELECT * FROM incident_reports WHERE id = ?", (cur.lastrowid,)).fetchone()
    conn.close()
    return row_to_report(row)

@router.post("/{report_id}/upvote", response_model=UpvoteResponse, summary="Upvote a report")
def upvote_report(report_id: int):
    conn = get_connection()
    row = conn.execute("SELECT * FROM incident_reports WHERE id = ?", (report_id,)).fetchone()
    if not row:
        conn.close()
        raise HTTPException(status_code=404, detail="Report not found")
    conn.execute("UPDATE incident_reports SET upvotes = upvotes + 1 WHERE id = ?", (report_id,))
    conn.commit()
    new_count = conn.execute("SELECT upvotes FROM incident_reports WHERE id = ?", (report_id,)).fetchone()[0]
    conn.close()
    return {"id": report_id, "upvotes": new_count, "message": "Upvote recorded"}

@router.patch("/{report_id}/status", summary="Update report status (admin)")
def update_status(report_id: int, status: str = Query(..., pattern="^(open|in_review|resolved)$")):
    conn = get_connection()
    row = conn.execute("SELECT * FROM incident_reports WHERE id = ?", (report_id,)).fetchone()
    if not row:
        conn.close()
        raise HTTPException(status_code=404, detail="Report not found")
    conn.execute("UPDATE incident_reports SET status = ? WHERE id = ?", (status, report_id))
    conn.commit()
    conn.close()
    return {"id": report_id, "status": status, "message": f"Report status updated to {status}"}
