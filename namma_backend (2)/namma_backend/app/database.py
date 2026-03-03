import sqlite3
import os
from datetime import datetime, timedelta
import random

DB_PATH = os.getenv("DB_PATH", "namma_commute.db")

def get_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    return conn

def init_db():
    conn = get_connection()
    cur = conn.cursor()

    # --- Traffic Incidents ---
    cur.execute("""
        CREATE TABLE IF NOT EXISTS traffic_incidents (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            title       TEXT NOT NULL,
            location    TEXT NOT NULL,
            latitude    REAL,
            longitude   REAL,
            type        TEXT NOT NULL,  -- accident, construction, flood, event, signal, pothole
            severity    TEXT NOT NULL,  -- critical, high, moderate, low
            description TEXT,
            reported_at TEXT NOT NULL,
            is_active   INTEGER DEFAULT 1,
            upvotes     INTEGER DEFAULT 0,
            source      TEXT DEFAULT 'system'
        )
    """)

    # --- Metro Lines ---
    cur.execute("""
        CREATE TABLE IF NOT EXISTS metro_lines (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            name        TEXT NOT NULL,
            color       TEXT NOT NULL,
            start_station TEXT NOT NULL,
            end_station   TEXT NOT NULL,
            total_stations INTEGER,
            distance_km   REAL,
            frequency_min INTEGER
        )
    """)

    # --- Metro Stations ---
    cur.execute("""
        CREATE TABLE IF NOT EXISTS metro_stations (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            line_id     INTEGER REFERENCES metro_lines(id),
            name        TEXT NOT NULL,
            sequence    INTEGER NOT NULL,
            is_hub      INTEGER DEFAULT 0,
            latitude    REAL,
            longitude   REAL
        )
    """)

    # --- Metro Schedule ---
    cur.execute("""
        CREATE TABLE IF NOT EXISTS metro_schedule (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            line_id      INTEGER REFERENCES metro_lines(id),
            from_station TEXT NOT NULL,
            to_station   TEXT NOT NULL,
            departure    TEXT NOT NULL,
            arrival      TEXT NOT NULL,
            status       TEXT DEFAULT 'on_time'  -- on_time, delayed, cancelled
        )
    """)

    # --- User Incident Reports ---
    cur.execute("""
        CREATE TABLE IF NOT EXISTS incident_reports (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            type        TEXT NOT NULL,  -- pothole, accident, signal_issue, waterlogging, road_block, no_lighting
            location    TEXT NOT NULL,
            area        TEXT NOT NULL,
            latitude    REAL,
            longitude   REAL,
            description TEXT,
            severity    TEXT DEFAULT 'moderate',
            reporter_id TEXT,
            reported_at TEXT NOT NULL,
            status      TEXT DEFAULT 'open',  -- open, in_review, resolved
            upvotes     INTEGER DEFAULT 0
        )
    """)

    # --- SOS Alerts ---
    cur.execute("""
        CREATE TABLE IF NOT EXISTS sos_alerts (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id     TEXT,
            latitude    REAL NOT NULL,
            longitude   REAL NOT NULL,
            location_text TEXT,
            alert_type  TEXT DEFAULT 'emergency',  -- emergency, accident, medical, fire
            message     TEXT,
            created_at  TEXT NOT NULL,
            status      TEXT DEFAULT 'active',  -- active, responded, resolved
            contact_name TEXT,
            contact_phone TEXT
        )
    """)

    # --- Emergency Contacts ---
    cur.execute("""
        CREATE TABLE IF NOT EXISTS emergency_contacts (
            id      INTEGER PRIMARY KEY AUTOINCREMENT,
            name    TEXT NOT NULL,
            number  TEXT NOT NULL,
            type    TEXT NOT NULL,   -- police, ambulance, fire, bbmp, traffic
            area    TEXT DEFAULT 'citywide'
        )
    """)

    conn.commit()
    conn.close()

def seed_db():
    conn = get_connection()
    cur = conn.cursor()

    # Only seed if empty
    cur.execute("SELECT COUNT(*) FROM traffic_incidents")
    if cur.fetchone()[0] > 0:
        conn.close()
        return

    now = datetime.now()

    # --- Traffic Incidents ---
    incidents = [
        ("Accident — 3 vehicles", "Silk Board Junction", 12.9166, 77.6224, "accident", "critical", "3-vehicle collision blocking 2 lanes. Police on site."),
        ("Waterlogging", "Bellandur Underpass", 12.9270, 77.6769, "flood", "critical", "Heavy waterlogging after rain. Avoid this stretch."),
        ("Road Construction", "Outer Ring Road, Marathahalli", 12.9564, 77.7010, "construction", "high", "BBMP road widening. Single lane operational."),
        ("Signal Malfunction", "Hebbal Flyover Junction", 13.0358, 77.5970, "signal", "high", "Traffic signal not working. Manual control deployed."),
        ("Event Diversion", "MG Road, Brigade Road", 12.9758, 77.6096, "event", "moderate", "Cultural event — road closed 6 PM to 10 PM."),
        ("Pothole Reported", "Sarjapur Road, Carmelaram", 12.9121, 77.7048, "pothole", "moderate", "Large pothole causing slowdown."),
        ("Flooding", "KR Puram Bridge", 13.0041, 77.6963, "flood", "high", "Flash flooding on service road. Main road open."),
        ("Debris on Road", "Tumkur Road, Peenya", 13.0283, 77.5190, "accident", "low", "Minor incident cleared but debris remains."),
    ]
    for inc in incidents:
        delta = timedelta(minutes=random.randint(10, 180))
        reported = (now - delta).isoformat()
        cur.execute("""
            INSERT INTO traffic_incidents (title, location, latitude, longitude, type, severity, description, reported_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (*inc, reported))

    # --- Metro Lines ---
    cur.execute("""
        INSERT INTO metro_lines (name, color, start_station, end_station, total_stations, distance_km, frequency_min)
        VALUES ('Purple Line', '#7B2D8B', 'Challaghatta', 'Baiyappanahalli', 19, 42.3, 6)
    """)
    purple_id = cur.lastrowid

    cur.execute("""
        INSERT INTO metro_lines (name, color, start_station, end_station, total_stations, distance_km, frequency_min)
        VALUES ('Green Line', '#1D8348', 'Nagasandra', 'Silk Board', 21, 24.2, 8)
    """)
    green_id = cur.lastrowid

    # --- Purple Line Stations ---
    purple_stations = [
        "Challaghatta", "Kengeri", "Jnanabharathi", "Rajarajeshwari Nagar",
        "Nayandahalli", "Mysore Road", "Deepanjali Nagar", "Attiguppe",
        "Vijayanagar", "Magadi Road", "City Railway Station", "Majestic",
        "Cubbon Park", "MG Road", "Trinity", "Halasuru",
        "Indiranagar", "Swami Vivekananda Road", "Baiyappanahalli"
    ]
    hubs = {"Majestic", "MG Road", "Indiranagar", "Cubbon Park"}
    for i, name in enumerate(purple_stations, 1):
        cur.execute("""
            INSERT INTO metro_stations (line_id, name, sequence, is_hub)
            VALUES (?, ?, ?, ?)
        """, (purple_id, name, i, 1 if name in hubs else 0))

    # --- Green Line Stations ---
    green_stations = [
        "Nagasandra", "Dasarahalli", "Jalahalli", "Peenya Industry",
        "Peenya", "Goraguntepalya", "Yeshwanthpur", "Sandal Soap Factory",
        "Mahalakshmi", "Rajajinagar", "Kuvempu Road", "Srirampura",
        "Mantri Square", "Majestic", "Sir MV", "Vidhana Soudha",
        "Cubbon Park", "Shivaji Nagar", "Ulsoor", "Halasuru", "Indiranagar"
    ]
    for i, name in enumerate(green_stations, 1):
        cur.execute("""
            INSERT INTO metro_stations (line_id, name, sequence, is_hub)
            VALUES (?, ?, ?, ?)
        """, (green_id, name, i, 1 if name in hubs else 0))

    # --- Metro Schedule (next trains) ---
    schedules = [
        (purple_id, "MG Road", "Majestic", "3 min", "9 min", "on_time"),
        (purple_id, "MG Road", "Baiyappanahalli", "7 min", "18 min", "on_time"),
        (purple_id, "Indiranagar", "Majestic", "5 min", "14 min", "delayed"),
        (green_id,  "Majestic", "Yeshwanthpur", "4 min", "12 min", "on_time"),
        (green_id,  "Cubbon Park", "Nagasandra", "9 min", "32 min", "on_time"),
        (green_id,  "Majestic", "Indiranagar", "6 min", "15 min", "on_time"),
    ]
    for s in schedules:
        cur.execute("""
            INSERT INTO metro_schedule (line_id, from_station, to_station, departure, arrival, status)
            VALUES (?, ?, ?, ?, ?, ?)
        """, s)

    # --- Emergency Contacts ---
    contacts = [
        ("Traffic Police Control", "103", "police", "citywide"),
        ("Ambulance", "108", "ambulance", "citywide"),
        ("BBMP Control Room", "1533", "bbmp", "citywide"),
        ("Fire & Emergency", "101", "fire", "citywide"),
        ("Women's Helpline", "1091", "police", "citywide"),
        ("Disaster Management", "1070", "police", "citywide"),
        ("Namma Metro Helpline", "080-49007000", "metro", "citywide"),
        ("BMTC Helpline", "080-22253311", "bmtc", "citywide"),
    ]
    for c in contacts:
        cur.execute("""
            INSERT INTO emergency_contacts (name, number, type, area)
            VALUES (?, ?, ?, ?)
        """, c)

    conn.commit()
    conn.close()
    print("✅ Database seeded successfully")
