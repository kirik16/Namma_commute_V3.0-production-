"""
OpenWeatherMap service for Bengaluru weather data.
Caches results to avoid hitting API rate limits.
Refreshes every 10 minutes (weather doesn't change every 30s).
"""
import os
import time
import urllib.request
import urllib.parse
import json
from datetime import datetime

# Bengaluru coordinates
BENGALURU_LAT = 12.9716
BENGALURU_LON = 77.5946

# Cache
_weather_cache = {
    "data":       None,
    "fetched_at": 0,
    "ttl_sec":    600,  # 10 minutes
}

FALLBACK_WEATHER = {
    "main":       "Clear",
    "description":"clear sky",
    "temp":       28,
    "feels_like": 30,
    "humidity":   65,
    "wind_speed": 3.5,
    "visibility": 10000,
    "rain_1h":    0,
    "source":     "fallback",
    "fetched_at": datetime.now().isoformat(),
}

def get_weather() -> dict:
    """
    Return current Bengaluru weather.
    Uses cache if fresh, otherwise fetches from OpenWeatherMap.
    Falls back to realistic defaults if API key missing or request fails.
    """
    api_key = os.getenv("OPENWEATHER_API_KEY", "")
    now = time.time()

    # Return cache if still fresh
    if _weather_cache["data"] and (now - _weather_cache["fetched_at"]) < _weather_cache["ttl_sec"]:
        return _weather_cache["data"]

    # No API key — return fallback
    if not api_key or api_key == "your_api_key_here":
        fallback = dict(FALLBACK_WEATHER)
        fallback["fetched_at"] = datetime.now().isoformat()
        fallback["note"] = "Set OPENWEATHER_API_KEY env variable for live weather"
        _weather_cache["data"] = fallback
        _weather_cache["fetched_at"] = now
        return fallback

    # Fetch from OpenWeatherMap
    try:
        url = (
            f"https://api.openweathermap.org/data/2.5/weather"
            f"?lat={BENGALURU_LAT}&lon={BENGALURU_LON}"
            f"&appid={api_key}&units=metric"
        )
        req = urllib.request.Request(url, headers={"User-Agent": "NammaCommute/1.0"})
        with urllib.request.urlopen(req, timeout=5) as resp:
            raw = json.loads(resp.read())

        weather = {
            "main":        raw["weather"][0]["main"],
            "description": raw["weather"][0]["description"],
            "temp":        raw["main"]["temp"],
            "feels_like":  raw["main"]["feels_like"],
            "humidity":    raw["main"]["humidity"],
            "wind_speed":  raw["wind"]["speed"],
            "visibility":  raw.get("visibility", 10000),
            "rain_1h":     raw.get("rain", {}).get("1h", 0),
            "source":      "openweathermap",
            "fetched_at":  datetime.now().isoformat(),
        }

        _weather_cache["data"] = weather
        _weather_cache["fetched_at"] = now
        return weather

    except Exception as e:
        # Return stale cache if available, else fallback
        if _weather_cache["data"]:
            stale = dict(_weather_cache["data"])
            stale["source"] = "stale_cache"
            return stale

        fallback = dict(FALLBACK_WEATHER)
        fallback["error"] = str(e)
        fallback["fetched_at"] = datetime.now().isoformat()
        return fallback

def get_weather_summary(weather: dict) -> str:
    """Human-readable weather summary for API responses."""
    temp  = weather.get("temp", 28)
    desc  = weather.get("description", "clear").title()
    humid = weather.get("humidity", 65)
    rain  = weather.get("rain_1h", 0)

    summary = f"{desc}, {temp:.0f}°C, Humidity {humid}%"
    if rain > 0:
        summary += f", Rain {rain:.1f}mm/hr"
    return summary
