from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from typing import Optional
import sqlite3, os, random, datetime, asyncio

app = FastAPI(title="Namma Commute API", version="1.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

DB = "namma_commute.db"
OPENWEATHER_KEY = os.getenv("OPENWEATHER_API_KEY", "")

# ─── DATABASE ────────────────────────────────────────────────────────────────

def get_db():
    conn = sqlite3.connect(DB)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db()
    c = conn.cursor()
    c.execute("""CREATE TABLE IF NOT EXISTS incidents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL, location TEXT NOT NULL, area TEXT NOT NULL,
        description TEXT, severity TEXT DEFAULT 'moderate',
        upvotes INTEGER DEFAULT 0, status TEXT DEFAULT 'active',
        reported_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)""")
    c.execute("""CREATE TABLE IF NOT EXISTS reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL, location TEXT NOT NULL, area TEXT NOT NULL,
        description TEXT, severity TEXT DEFAULT 'moderate',
        upvotes INTEGER DEFAULT 0, status TEXT DEFAULT 'open',
        reported_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)""")
    c.execute("""CREATE TABLE IF NOT EXISTS sos_alerts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT, latitude REAL, longitude REAL,
        location_text TEXT, alert_type TEXT, message TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)""")

    c.execute("SELECT COUNT(*) FROM incidents")
    if c.fetchone()[0] == 0:
        seeds = [
            ("accident","Silk Board Junction","Koramangala","Multi-vehicle collision blocking 2 lanes","critical",24),
            ("construction","Hebbal Flyover","Hebbal","Metro construction reducing lanes","high",18),
            ("flood","Marathahalli Bridge","Marathahalli","Waterlogging after heavy rain","high",15),
            ("signal","KR Puram Signal","Whitefield","Signal malfunction causing heavy backlog","moderate",9),
            ("accident","Outer Ring Road, Kadubeesanahalli","Marathahalli","Minor fender bender, partially cleared","moderate",7),
            ("pothole","Hosur Road near Bommanahalli","Electronic City","Large pothole causing lane closure","high",12),
            ("construction","Bannerghatta Road","Jayanagar","Road widening work in progress","moderate",5),
            ("accident","MG Road near Trinity Circle","MG Road","Vehicle breakdown blocking fast lane","low",3),
        ]
        c.executemany("INSERT INTO incidents (type,location,area,description,severity,upvotes) VALUES (?,?,?,?,?,?)", seeds)

    c.execute("SELECT COUNT(*) FROM reports")
    if c.fetchone()[0] == 0:
        seeds = [
            ("pothole","80 Feet Road, Koramangala","Koramangala","Deep pothole near 4th block signal","high",11),
            ("no_lighting","Kanakapura Road","Jayanagar","Street lights not working for 3 days","moderate",6),
            ("waterlogging","HSR Layout Sector 6","HSR Layout","Water stagnation after yesterday rain","moderate",8),
            ("signal_issue","Tin Factory Junction","Whitefield","Signal cycling too fast","moderate",4),
            ("road_block","Nagawara Ring Road","Hebbal","Fallen tree blocking one lane","high",9),
        ]
        c.executemany("INSERT INTO reports (type,location,area,description,severity,upvotes) VALUES (?,?,?,?,?,?)", seeds)

    conn.commit()
    conn.close()

init_db()

# ─── STATIC DATA ──────────────────────────────────────────────────────────────

JUNCTIONS = [
    {"junction":"Silk Board Junction","delay_min":25,"severity":"critical","message":"Multi-vehicle accident + peak hour congestion"},
    {"junction":"Hebbal Flyover","delay_min":18,"severity":"high","message":"Metro construction reducing lanes"},
    {"junction":"Marathahalli Bridge","delay_min":15,"severity":"high","message":"Waterlogging + heavy IT traffic"},
    {"junction":"KR Puram Signal","delay_min":12,"severity":"moderate","message":"Signal malfunction, police deployed"},
    {"junction":"Tin Factory Junction","delay_min":10,"severity":"moderate","message":"TTMC bus bunching"},
    {"junction":"Jayadeva Flyover","delay_min":8,"severity":"moderate","message":"Steady IT office traffic"},
    {"junction":"Bannerghatta Rd, Arekere","delay_min":7,"severity":"low","message":"School traffic dispersing"},
    {"junction":"Yeshwanthpur Circle","delay_min":6,"severity":"low","message":"Normal congestion"},
]

METRO_LINES = [
    {"id":1,"name":"Purple Line","color":"#7B2D8B","total_stations":37,"distance_km":43.5,"frequency_min":5,"operating_hours":"5:30 AM - 11:00 PM"},
    {"id":2,"name":"Green Line","color":"#2E7D32","total_stations":16,"distance_km":24.2,"frequency_min":8,"operating_hours":"5:30 AM - 11:00 PM"},
]

PURPLE_STATIONS = [
    {"name":"Challaghatta","is_hub":False},{"name":"Vajarahalli","is_hub":False},
    {"name":"Thalaghattapura","is_hub":False},{"name":"Silk Institute","is_hub":False},
    {"name":"JP Nagar","is_hub":False},{"name":"Yelachenahalli","is_hub":False},
    {"name":"Konanakunte Cross","is_hub":False},{"name":"Doddakallasandra","is_hub":False},
    {"name":"Uttarahalli","is_hub":False},{"name":"Nayandahalli","is_hub":False},
    {"name":"Rajarajeshwari Nagar","is_hub":False},{"name":"Mysuru Road","is_hub":True},
    {"name":"Kengeri Bus Terminal","is_hub":True},{"name":"Hosahalli","is_hub":False},
    {"name":"Vijayanagar","is_hub":False},{"name":"Attiguppe","is_hub":False},
    {"name":"Deepanjali Nagar","is_hub":False},{"name":"Magadi Road","is_hub":False},
    {"name":"City Railway Station","is_hub":True},{"name":"Majestic","is_hub":True},
    {"name":"Chickpete","is_hub":False},{"name":"KR Market","is_hub":True},
    {"name":"National College","is_hub":False},{"name":"Lalbagh","is_hub":False},
    {"name":"South End Circle","is_hub":False},{"name":"Jayanagar","is_hub":False},
    {"name":"Rashtriya Vidyalaya Road","is_hub":False},{"name":"Banashankari","is_hub":True},
    {"name":"Jayaprakash Nagar","is_hub":False},{"name":"Trinity","is_hub":False},
    {"name":"MG Road","is_hub":True},{"name":"Cubbon Park","is_hub":False},
    {"name":"Vidhana Soudha","is_hub":False},{"name":"Sir M Visveshwaraya","is_hub":False},
    {"name":"Baiyappanahalli","is_hub":True},{"name":"Swami Vivekananda Road","is_hub":False},
    {"name":"Whitefield (Kadugodi)","is_hub":True},
]

GREEN_STATIONS = [
    {"name":"Nagasandra","is_hub":True},{"name":"Dasarahalli","is_hub":False},
    {"name":"Jalahalli","is_hub":False},{"name":"Peenya Industry","is_hub":False},
    {"name":"Peenya","is_hub":True},{"name":"Goraguntepalya","is_hub":False},
    {"name":"Yeshwanthpur","is_hub":True},{"name":"Sandal Soap Factory","is_hub":False},
    {"name":"Mahalakshmi","is_hub":False},{"name":"Rajajinagar","is_hub":True},
    {"name":"Mahakavi Kuvempu Road","is_hub":False},{"name":"Srirampura","is_hub":False},
    {"name":"Mantri Square Sampige Road","is_hub":False},{"name":"Majestic","is_hub":True},
    {"name":"Chickpete","is_hub":False},{"name":"KR Market","is_hub":True},
]

_sync_count = 0

# ─── HELPERS ──────────────────────────────────────────────────────────────────

def jitter(val, pct=0.15):
    return max(1, int(val * (1 + random.uniform(-pct, pct))))

async def get_weather():
    if not OPENWEATHER_KEY:
        return {
            "current":{"temp":28.5,"main":"Clear","description":"clear sky","humidity":65,"wind_speed":3.2,"rain_1h":0},
            "summary":"Clear skies over Bengaluru"
        }
    try:
        import httpx
        async with httpx.AsyncClient(timeout=5) as client:
            r = await client.get(f"https://api.openweathermap.org/data/2.5/weather?q=Bangalore,IN&appid={OPENWEATHER_KEY}&units=metric")
            d = r.json()
            return {
                "current":{
                    "temp":d["main"]["temp"],"main":d["weather"][0]["main"],
                    "description":d["weather"][0]["description"],"humidity":d["main"]["humidity"],
                    "wind_speed":d["wind"]["speed"],"rain_1h":d.get("rain",{}).get("1h",0),
                },
                "summary":d["weather"][0]["description"]
            }
    except:
        return {"current":{"temp":29.0,"main":"Clouds","description":"partly cloudy","humidity":70,"wind_speed":2.8,"rain_1h":0},"summary":"Partly cloudy"}

def next_trains(freq_min: int):
    now = datetime.datetime.now()
    trains = []
    for i in range(1, 5):
        dep_min = i * freq_min + random.randint(-1, 2)
        dep_time = now + datetime.timedelta(minutes=dep_min)
        trains.append({
            "from_station":"Current Station","to_station":"Terminal",
            "departure":f"{dep_min} min","departure_time":dep_time.strftime("%H:%M"),
            "status":"on_time" if random.random() > 0.2 else "slight_delay",
            "platform":random.randint(1,2),
        })
    return trains

# ─── AI ENDPOINTS ─────────────────────────────────────────────────────────────

@app.get("/api/v1/ai/live")
async def ai_live():
    global _sync_count
    _sync_count += 1
    conn = get_db()
    c = conn.cursor()
    c.execute("SELECT COUNT(*) FROM incidents WHERE status='active' AND severity='critical'")
    critical = c.fetchone()[0]
    c.execute("SELECT COUNT(*) FROM incidents WHERE status='active'")
    total = c.fetchone()[0]
    conn.close()
    index = max(20, min(95, 85 - critical * 10 - total * 2 + random.randint(-3,3)))
    label = "GOOD" if index > 70 else "MODERATE" if index > 50 else "HEAVY" if index > 30 else "SEVERE"
    hotspots = [dict(j) for j in JUNCTIONS[:6]]
    for h in hotspots:
        h["delay_min"] = jitter(h["delay_min"])
    weather = await get_weather()
    return {
        "traffic":{"city_index":{"index":index,"label":label,"critical_count":critical,"total_incidents":total},"junctions":hotspots},
        "weather":weather,
        "sync":{"cycle_count":_sync_count,"last_updated":datetime.datetime.utcnow().isoformat()},
    }

@app.get("/api/v1/ai/traffic/hotspots")
async def ai_hotspots():
    hotspots = [dict(j) for j in JUNCTIONS]
    for h in hotspots:
        h["delay_min"] = jitter(h["delay_min"])
    return {"hotspots": hotspots}

@app.get("/api/v1/ai/metro/status")
async def ai_metro_status():
    return {"lines":[
        {"line_id":1,"status":"on_time","delay_min":0,"reasons":["Services running normally"]},
        {"line_id":2,"status":"slight_delay","delay_min":4,"reasons":["Passenger rush at Majestic interchange"]},
    ]}

@app.get("/api/v1/ai/routes/recommend")
async def ai_route(origin: str = "", destination: str = ""):
    return {"origin":origin,"destination":destination,
            "recommended":"Via NICE Road — saves ~18 min",
            "alternatives":["Via ORR (+8 min)","Via Bannerghatta Rd (+12 min)"],
            "metro_option":"Take Purple Line from MG Road → interchange at Majestic"}

# ─── TRAFFIC ENDPOINTS ────────────────────────────────────────────────────────

@app.get("/api/v1/traffic/summary")
async def traffic_summary():
    conn = get_db()
    c = conn.cursor()
    c.execute("SELECT COUNT(*) FROM incidents WHERE status='active'")
    total = c.fetchone()[0]
    c.execute("SELECT COUNT(*) FROM incidents WHERE status='active' AND severity='critical'")
    critical = c.fetchone()[0]
    conn.close()
    return {"total_active_incidents":total,"critical_incidents":critical,"traffic_index":max(20,80-critical*10-total*2)}

@app.get("/api/v1/traffic/")
async def get_incidents(severity: Optional[str] = None, type: Optional[str] = None):
    conn = get_db()
    q = "SELECT * FROM incidents WHERE status='active'"
    params = []
    if severity: q += " AND severity=?"; params.append(severity)
    if type: q += " AND type=?"; params.append(type)
    q += " ORDER BY CASE severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'moderate' THEN 3 ELSE 4 END"
    rows = [dict(r) for r in conn.execute(q, params).fetchall()]
    conn.close()
    return rows

@app.post("/api/v1/traffic/")
async def create_incident(data: dict):
    conn = get_db()
    c = conn.cursor()
    c.execute("INSERT INTO incidents (type,location,area,description,severity) VALUES (?,?,?,?,?)",
              (data.get("type","accident"),data.get("location","Unknown"),data.get("area","Bengaluru"),
               data.get("description"),data.get("severity","moderate")))
    conn.commit()
    row = dict(c.execute("SELECT * FROM incidents WHERE id=?", (c.lastrowid,)).fetchone())
    conn.close()
    return row

@app.post("/api/v1/traffic/{id}/upvote")
async def upvote_incident(id: int):
    conn = get_db()
    conn.execute("UPDATE incidents SET upvotes=upvotes+1 WHERE id=?", (id,))
    conn.commit()
    row = dict(conn.execute("SELECT * FROM incidents WHERE id=?", (id,)).fetchone())
    conn.close()
    return row

# ─── METRO ENDPOINTS ──────────────────────────────────────────────────────────

@app.get("/api/v1/metro/lines")
async def metro_lines():
    return METRO_LINES

@app.get("/api/v1/metro/lines/{line_id}/stations")
async def metro_stations(line_id: int):
    return PURPLE_STATIONS if line_id == 1 else GREEN_STATIONS

@app.get("/api/v1/metro/lines/{line_id}/schedule")
async def metro_schedule(line_id: int, from_station: Optional[str] = None):
    freq = 5 if line_id == 1 else 8
    return next_trains(freq)

@app.get("/api/v1/metro/status")
async def metro_status():
    return {"status":"operational","last_updated":datetime.datetime.utcnow().isoformat()}

@app.get("/api/v1/metro/fare")
async def metro_fare(line_id: int, from_station: str, to_station: str):
    stations = PURPLE_STATIONS if line_id == 1 else GREEN_STATIONS
    names = [s["name"] for s in stations]
    try:
        stops = abs(names.index(to_station) - names.index(from_station))
    except ValueError:
        stops = 5
    fare = 10 if stops <= 2 else 20 if stops <= 5 else 30 if stops <= 10 else 40 if stops <= 15 else 60
    return {"fare_inr":fare,"stops":stops,"from":from_station,"to":to_station,"note":"BMRCL 2024 fare chart"}

# ─── REPORTS ENDPOINTS ────────────────────────────────────────────────────────

@app.get("/api/v1/reports/")
async def get_reports(status: Optional[str] = None, area: Optional[str] = None):
    conn = get_db()
    q = "SELECT * FROM reports WHERE 1=1"
    params = []
    if status: q += " AND status=?"; params.append(status)
    if area: q += " AND area=?"; params.append(area)
    q += " ORDER BY reported_at DESC"
    rows = [dict(r) for r in conn.execute(q, params).fetchall()]
    conn.close()
    return rows

@app.post("/api/v1/reports/")
async def submit_report(data: dict):
    conn = get_db()
    c = conn.cursor()
    c.execute("INSERT INTO reports (type,location,area,description,severity) VALUES (?,?,?,?,?)",
              (data.get("type","pothole"),data.get("location","Unknown"),data.get("area","Bengaluru"),
               data.get("description"),data.get("severity","moderate")))
    conn.commit()
    row = dict(c.execute("SELECT * FROM reports WHERE id=?", (c.lastrowid,)).fetchone())
    conn.close()
    return row

@app.post("/api/v1/reports/{id}/upvote")
async def upvote_report(id: int):
    conn = get_db()
    conn.execute("UPDATE reports SET upvotes=upvotes+1 WHERE id=?", (id,))
    conn.commit()
    row = dict(conn.execute("SELECT * FROM reports WHERE id=?", (id,)).fetchone())
    conn.close()
    return row

# ─── SOS ENDPOINTS ────────────────────────────────────────────────────────────

@app.post("/api/v1/sos/alert")
async def sos_alert(data: dict):
    conn = get_db()
    conn.execute("INSERT INTO sos_alerts (user_id,latitude,longitude,location_text,alert_type,message) VALUES (?,?,?,?,?,?)",
                 (data.get("user_id"),data.get("latitude"),data.get("longitude"),
                  data.get("location_text"),data.get("alert_type","emergency"),data.get("message")))
    conn.commit()
    conn.close()
    return {"status":"received","message":"SOS alert logged. Stay safe!","timestamp":datetime.datetime.utcnow().isoformat()}

@app.get("/api/v1/sos/contacts")
async def sos_contacts():
    return [
        {"name":"Traffic Police","number":"103","type":"police","available":"24/7"},
        {"name":"Ambulance","number":"108","type":"ambulance","available":"24/7"},
        {"name":"BBMP Helpline","number":"1533","type":"bbmp","available":"24/7"},
        {"name":"Fire Services","number":"101","type":"fire","available":"24/7"},
        {"name":"Women Helpline","number":"1091","type":"police","available":"24/7"},
        {"name":"Disaster Helpline","number":"1077","type":"fire","available":"24/7"},
    ]

@app.get("/api/v1/sos/guidance")
async def sos_guidance():
    return {"steps":[
        {"step":1,"title":"Stay Calm","desc":"Assess yourself for injuries before moving."},
        {"step":2,"title":"Call Emergency","desc":"Call 108 for ambulance or 103 for Traffic Police."},
        {"step":3,"title":"Tap SOS Button","desc":"Use the SOS button to share your GPS coordinates."},
        {"step":4,"title":"Don't Move Vehicle","desc":"Keep vehicles in place until police arrive."},
        {"step":5,"title":"Warn Other Drivers","desc":"Turn on hazard lights if available."},
        {"step":6,"title":"Document Scene","desc":"Take photos of damage and number plates if safe."},
    ]}

# ─── HEALTH ───────────────────────────────────────────────────────────────────

@app.get("/")
async def root():
    return {"status":"Namma Commute API is live","version":"1.0.0","docs":"/docs"}

@app.get("/health")
async def health():
    return {"status":"healthy","timestamp":datetime.datetime.utcnow().isoformat()}
