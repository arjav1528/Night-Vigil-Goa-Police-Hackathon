from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime

class UserOut(BaseModel):
    id: str
    empid: str
    role: str
    profileImage: Optional[List[str]] = None
    createdAt: datetime




class DutyCreateSchema(BaseModel):
    officerId: str
    location: str
    latitude: float
    longitude: float
    radius: float = 100
    startTime: datetime
    endTime: datetime

class CheckInSchema(BaseModel):
    latitude: float
    longitude: float
    selfieUrl: str
    remarks: Optional[str] = None

class LocationUpdateSchema(BaseModel):
    latitude: float
    longitude: float


class LocationUpdateRequest(BaseModel):
    latitude: float
    longitude: float
    dutyId: str
    location_verified: bool