from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime

# ─────────────────────────────────────────
# TRAFFIC INCIDENTS
# ─────────────────────────────────────────

class TrafficIncident(BaseModel):
    id: int
    title: str
    location: str
    latitude: Optional[float]
    longitude: Optional[float]
    type: str
    severity: str
    description: Optional[str]
    reported_at: str
    is_active: bool
    upvotes: int
    source: str

class TrafficIncidentCreate(BaseModel):
    title: str = Field(..., min_length=3, max_length=100)
    location: str = Field(..., min_length=3)
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    type: str = Field(..., pattern="^(accident|construction|flood|event|signal|pothole)$")
    severity: str = Field(..., pattern="^(critical|high|moderate|low)$")
    description: Optional[str] = None

# ─────────────────────────────────────────
# METRO
# ─────────────────────────────────────────

class MetroLine(BaseModel):
    id: int
    name: str
    color: str
    start_station: str
    end_station: str
    total_stations: int
    distance_km: float
    frequency_min: int

class MetroStation(BaseModel):
    id: int
    line_id: int
    name: str
    sequence: int
    is_hub: bool
    latitude: Optional[float]
    longitude: Optional[float]

class MetroScheduleItem(BaseModel):
    id: int
    line_id: int
    from_station: str
    to_station: str
    departure: str
    arrival: str
    status: str

# ─────────────────────────────────────────
# INCIDENT REPORTS
# ─────────────────────────────────────────

class IncidentReport(BaseModel):
    id: int
    type: str
    location: str
    area: str
    latitude: Optional[float]
    longitude: Optional[float]
    description: Optional[str]
    severity: str
    reporter_id: Optional[str]
    reported_at: str
    status: str
    upvotes: int

class IncidentReportCreate(BaseModel):
    type: str = Field(..., pattern="^(pothole|accident|signal_issue|waterlogging|road_block|no_lighting)$")
    location: str = Field(..., min_length=3)
    area: str = Field(..., min_length=2)
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    description: Optional[str] = None
    severity: str = Field(default="moderate", pattern="^(critical|high|moderate|low)$")
    reporter_id: Optional[str] = None

# ─────────────────────────────────────────
# SOS
# ─────────────────────────────────────────

class SOSAlert(BaseModel):
    id: int
    user_id: Optional[str]
    latitude: float
    longitude: float
    location_text: Optional[str]
    alert_type: str
    message: Optional[str]
    created_at: str
    status: str
    contact_name: Optional[str]
    contact_phone: Optional[str]

class SOSAlertCreate(BaseModel):
    user_id: Optional[str] = None
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    location_text: Optional[str] = None
    alert_type: str = Field(default="emergency", pattern="^(emergency|accident|medical|fire)$")
    message: Optional[str] = None
    contact_name: Optional[str] = None
    contact_phone: Optional[str] = None

class EmergencyContact(BaseModel):
    id: int
    name: str
    number: str
    type: str
    area: str

# ─────────────────────────────────────────
# COMMON
# ─────────────────────────────────────────

class UpvoteResponse(BaseModel):
    id: int
    upvotes: int
    message: str

class APIResponse(BaseModel):
    success: bool
    message: str
    data: Optional[dict] = None
