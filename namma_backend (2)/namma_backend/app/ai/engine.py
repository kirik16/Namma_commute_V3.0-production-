"""
Namma Commute AI Engine
- Traffic congestion prediction using weather + time patterns
- Metro delay detection using anomaly scoring
- Smart route recommendations using weighted graph
"""
import math
import random
from datetime import datetime
from typing import Optional


# ─────────────────────────────────────────────────────────────
# TRAFFIC CONGESTION PREDICTOR
# ─────────────────────────────────────────────────────────────

# Historical congestion weights per junction (0-1 scale)
JUNCTION_BASE_CONGESTION = {
    "Silk Board Junction":      0.92,
    "Marathahalli Bridge":      0.85,
    "KR Puram Signal":          0.80,
    "Hebbal Flyover":           0.75,
    "Tin Factory Junction":     0.72,
    "Electronic City Toll":     0.78,
    "Sarjapur Road":            0.70,
    "Bellary Road Hebbal":      0.65,
    "Outer Ring Road Bellandur":0.82,
    "Bannerghatta Road":        0.68,
    "Mysore Road Nayandahalli": 0.60,
    "Tumkur Road Peenya":       0.63,
}

def get_time_multiplier(dt: datetime) -> float:
    """
    Return a congestion multiplier based on hour and weekday.
    Peak hours: 8-10 AM, 5-8 PM on weekdays
    """
    hour = dt.hour
    is_weekday = dt.weekday() < 5  # Mon-Fri

    if not is_weekday:
        # Weekend: light traffic
        if 10 <= hour <= 20:
            return 0.55
        return 0.35

    # Weekday time bands
    if 7 <= hour <= 10:    # Morning peak
        return 1.0
    elif 17 <= hour <= 20: # Evening peak
        return 0.95
    elif 11 <= hour <= 16: # Midday
        return 0.60
    elif 21 <= hour <= 23: # Night
        return 0.30
    else:                   # Late night / early morning
        return 0.20

def get_weather_multiplier(weather: dict) -> float:
    """
    Increase congestion during rain, poor visibility, extreme heat.
    weather dict from OpenWeatherMap current API.
    """
    multiplier = 1.0

    condition = weather.get("main", "").lower()
    rain_mm   = weather.get("rain_1h", 0)
    wind_kph  = weather.get("wind_speed", 0) * 3.6  # m/s → kph
    visibility = weather.get("visibility", 10000)     # metres
    temp_c    = weather.get("temp", 28)

    # Rain impact
    if "rain" in condition or rain_mm > 0:
        if rain_mm > 10:
            multiplier += 0.40   # heavy rain
        elif rain_mm > 2:
            multiplier += 0.25   # moderate rain
        else:
            multiplier += 0.12   # drizzle

    # Thunderstorm
    if "thunderstorm" in condition:
        multiplier += 0.35

    # Low visibility (fog / mist)
    if visibility < 500:
        multiplier += 0.30
    elif visibility < 1500:
        multiplier += 0.15

    # High wind
    if wind_kph > 50:
        multiplier += 0.15

    # Extreme heat (people avoid travel, less congestion)
    if temp_c > 40:
        multiplier -= 0.10

    return min(multiplier, 2.0)  # cap at 2x

def predict_congestion(junction: str, weather: dict, dt: Optional[datetime] = None) -> dict:
    """
    Predict congestion level for a junction given current weather + time.
    Returns score 0-100 and human-readable severity.
    """
    if dt is None:
        dt = datetime.now()

    base    = JUNCTION_BASE_CONGESTION.get(junction, 0.65)
    time_m  = get_time_multiplier(dt)
    wx_m    = get_weather_multiplier(weather)

    # Small random noise (±3%) to simulate live variation
    noise   = random.uniform(-0.03, 0.03)

    raw_score = base * time_m * wx_m + noise
    score   = max(0, min(100, round(raw_score * 100)))

    if score >= 80:
        severity = "critical"
        color    = "#FF2D55"
        message  = "Severe gridlock. Avoid if possible."
    elif score >= 60:
        severity = "high"
        color    = "#FF9500"
        message  = "Heavy congestion. Allow extra 20-30 min."
    elif score >= 40:
        severity = "moderate"
        color    = "#FFCC00"
        message  = "Moderate traffic. Slight delays expected."
    else:
        severity = "low"
        color    = "#34C759"
        message  = "Traffic flowing smoothly."

    # Estimated delay in minutes
    delay_min = round((score / 100) * 55)

    return {
        "junction":    junction,
        "score":       score,
        "severity":    severity,
        "color":       color,
        "message":     message,
        "delay_min":   delay_min,
        "factors": {
            "base_congestion": round(base * 100),
            "time_factor":     round(time_m, 2),
            "weather_factor":  round(wx_m, 2),
        }
    }

def predict_all_junctions(weather: dict) -> list:
    now = datetime.now()
    results = []
    for junction in JUNCTION_BASE_CONGESTION:
        pred = predict_congestion(junction, weather, now)
        results.append(pred)
    # Sort by score descending
    results.sort(key=lambda x: x["score"], reverse=True)
    return results

def get_city_traffic_index(predictions: list) -> dict:
    """
    Aggregate junction predictions into a single city-wide index.
    """
    if not predictions:
        return {"index": 50, "label": "Unknown"}

    avg_score = sum(p["score"] for p in predictions) / len(predictions)
    critical  = sum(1 for p in predictions if p["severity"] == "critical")
    high      = sum(1 for p in predictions if p["severity"] == "high")

    # City index: lower = worse (like air quality index)
    city_index = max(0, round(100 - avg_score))

    if city_index < 25:
        label = "Gridlock"
    elif city_index < 45:
        label = "Severe Congestion"
    elif city_index < 60:
        label = "Heavy Traffic"
    elif city_index < 75:
        label = "Moderate"
    else:
        label = "Flowing"

    return {
        "index":            city_index,
        "label":            label,
        "avg_congestion":   round(avg_score),
        "critical_count":   critical,
        "high_count":       high,
        "total_junctions":  len(predictions),
    }


# ─────────────────────────────────────────────────────────────
# METRO DELAY DETECTOR
# ─────────────────────────────────────────────────────────────

def detect_metro_delays(weather: dict, dt: Optional[datetime] = None) -> list:
    """
    Detect likely metro delays based on:
    - Heavy rain (track flooding risk)
    - Rush hour (overcrowding → slower boarding)
    - Random technical events (simulated)
    """
    if dt is None:
        dt = datetime.now()

    hour      = dt.hour
    rain_mm   = weather.get("rain_1h", 0)
    condition = weather.get("main", "").lower()
    is_peak   = (7 <= hour <= 10) or (17 <= hour <= 20)

    lines = [
        {"id": 1, "name": "Purple Line", "color": "#7B2D8B",
         "stations": ["Challaghatta", "Kengeri", "Majestic", "MG Road", "Indiranagar", "Baiyappanahalli"]},
        {"id": 2, "name": "Green Line",  "color": "#1D8348",
         "stations": ["Nagasandra", "Yeshwanthpur", "Majestic", "Cubbon Park", "Shivaji Nagar"]},
    ]

    results = []
    for line in lines:
        delay_seconds = 0
        reasons       = []
        status        = "on_time"

        # Rush hour overcrowding
        if is_peak:
            delay_seconds += random.randint(30, 90)
            reasons.append("Rush hour — increased boarding time")

        # Rain impact on surface sections
        if rain_mm > 5 or "rain" in condition:
            delay_seconds += random.randint(60, 180)
            reasons.append("Rain — reduced speed on open sections")

        # Random technical event (5% chance)
        if random.random() < 0.05:
            delay_seconds += random.randint(120, 300)
            reasons.append("Signal check — brief technical hold")

        delay_min = round(delay_seconds / 60)

        if delay_seconds > 180:
            status = "delayed"
        elif delay_seconds > 60:
            status = "slight_delay"
        else:
            status = "on_time"
            reasons = ["Services running normally"]

        # Generate next 3 train arrivals
        next_trains = []
        base_gap = 6 if line["id"] == 1 else 8
        for i in range(3):
            eta = base_gap * (i + 1) + delay_min
            next_trains.append({
                "eta_min":   eta,
                "platform":  f"Platform {(i % 2) + 1}",
                "status":    status,
            })

        results.append({
            "line_id":       line["id"],
            "line_name":     line["name"],
            "color":         line["color"],
            "status":        status,
            "delay_min":     delay_min,
            "reasons":       reasons,
            "next_trains":   next_trains,
            "frequency_min": base_gap,
            "affected_stations": line["stations"] if status != "on_time" else [],
        })

    return results


# ─────────────────────────────────────────────────────────────
# SMART ROUTE RECOMMENDER
# ─────────────────────────────────────────────────────────────

# Road segments: (from, to, base_time_min, mode)
ROUTE_GRAPH = {
    ("Koramangala", "MG Road"):        {"road": 22, "metro": None,  "bus": 35},
    ("Koramangala", "Silk Board"):     {"road": 15, "metro": None,  "bus": 25},
    ("Indiranagar", "MG Road"):        {"road": 12, "metro": 8,     "bus": 20},
    ("Indiranagar", "Majestic"):       {"road": 28, "metro": 15,    "bus": 40},
    ("Whitefield", "MG Road"):         {"road": 45, "metro": None,  "bus": 60},
    ("Whitefield", "Marathahalli"):    {"road": 20, "metro": None,  "bus": 30},
    ("Electronic City", "Silk Board"): {"road": 30, "metro": None,  "bus": 45},
    ("HSR Layout", "Silk Board"):      {"road": 12, "metro": None,  "bus": 20},
    ("Hebbal", "Majestic"):            {"road": 25, "metro": None,  "bus": 40},
    ("Yeshwanthpur", "Majestic"):      {"road": 15, "metro": 10,    "bus": 25},
    ("Jayanagar", "MG Road"):          {"road": 20, "metro": None,  "bus": 32},
    ("BTM Layout", "Silk Board"):      {"road": 10, "metro": None,  "bus": 18},
}

def recommend_routes(origin: str, destination: str,
                     predictions: list, metro_delays: list,
                     weather: dict) -> dict:
    """
    Given congestion predictions and metro delays, recommend best route.
    """
    # Find matching route
    key = (origin, destination)
    rev_key = (destination, origin)
    segment = ROUTE_GRAPH.get(key) or ROUTE_GRAPH.get(rev_key)

    rain_mm = weather.get("rain_1h", 0)
    raining = rain_mm > 2

    # Get congestion along route (use avg of all if no direct match)
    avg_congestion = 55
    if predictions:
        avg_congestion = sum(p["score"] for p in predictions) / len(predictions)

    options = []

    # ── Road option ──
    if segment and segment.get("road"):
        base = segment["road"]
        congestion_factor = 1 + (avg_congestion / 100) * 0.8
        rain_factor = 1.15 if raining else 1.0
        eta = round(base * congestion_factor * rain_factor)
        congestion_pct = round(avg_congestion)

        options.append({
            "mode":         "road",
            "icon":         "🚗",
            "label":        "Drive / Cab",
            "eta_min":      eta,
            "congestion":   congestion_pct,
            "cost_inr":     f"₹{round(eta * 3.5)}–₹{round(eta * 5)}",
            "notes":        "Heavy rain — allow extra time" if raining else
                           ("High congestion" if avg_congestion > 65 else "Clear roads"),
            "recommended":  False,
        })

    # ── Metro option ──
    if segment and segment.get("metro") is not None:
        metro_delay = 0
        metro_status = "on_time"
        for m in metro_delays:
            if m["delay_min"] > 0:
                metro_delay = m["delay_min"]
                metro_status = m["status"]
                break

        metro_eta = segment["metro"] + metro_delay + 5  # +5 for walk to station
        options.append({
            "mode":         "metro",
            "icon":         "🚇",
            "label":        "Namma Metro",
            "eta_min":      metro_eta,
            "congestion":   0,
            "cost_inr":     "₹10–₹50",
            "notes":        f"Delay: {metro_delay} min" if metro_delay > 0 else "On time — recommended!",
            "recommended":  False,
            "metro_status": metro_status,
        })

    # ── Bus option ──
    if segment and segment.get("bus"):
        bus_eta = round(segment["bus"] * (1 + (avg_congestion / 100) * 0.5))
        options.append({
            "mode":         "bus",
            "icon":         "🚌",
            "label":        "BMTC Bus",
            "eta_min":      bus_eta,
            "congestion":   round(avg_congestion * 0.7),
            "cost_inr":     "₹5–₹35",
            "notes":        "Avoid during heavy rain" if raining else "Economical option",
            "recommended":  False,
        })

    # ── Auto/Cab if no data ──
    if not options:
        estimated_eta = 30 + round(avg_congestion * 0.3)
        options.append({
            "mode":     "road",
            "icon":     "🚗",
            "label":    "Cab / Auto",
            "eta_min":  estimated_eta,
            "cost_inr": f"₹{round(estimated_eta * 4)}–₹{round(estimated_eta * 6)}",
            "notes":    "No direct route data — estimate only",
            "recommended": False,
        })

    # Mark the fastest option as recommended
    if options:
        best = min(options, key=lambda x: x["eta_min"])
        best["recommended"] = True

    # Sort by ETA
    options.sort(key=lambda x: x["eta_min"])

    # AI advice
    if avg_congestion > 75:
        ai_advice = f"🔴 High congestion detected. Metro is strongly recommended if available."
    elif raining:
        ai_advice = f"🌧️ Rain detected. Add 15–20 min buffer. Metro avoids road delays."
    elif avg_congestion < 35:
        ai_advice = f"🟢 Roads are clear. Good time to travel by road."
    else:
        ai_advice = f"🟡 Moderate traffic. Check live updates before leaving."

    return {
        "origin":       origin,
        "destination":  destination,
        "options":      options,
        "ai_advice":    ai_advice,
        "congestion_index": round(avg_congestion),
        "weather_impact": "yes" if raining else "no",
    }
