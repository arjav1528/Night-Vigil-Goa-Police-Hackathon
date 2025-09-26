from pydantic import BaseModel, validator, Field
from typing import Optional, List
from datetime import datetime

class UserOut(BaseModel):
    id: str
    empid: str
    role: str
    profileImage: Optional[List[str]] = []
    createdAt: datetime

    @validator('empid')
    def validate_empid(cls, v):
        if not v or v.strip() == "":
            raise ValueError('empid cannot be empty')
        return v.strip()

    @validator('role')
    def validate_role(cls, v):
        if v not in ['ADMIN', 'OFFICER']:
            raise ValueError('role must be either ADMIN or OFFICER')
        return v

class DutyCreateSchema(BaseModel):
    officerId: str = Field(..., min_length=1)
    location: str = Field(..., min_length=1)
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    radius: float = Field(default=100, gt=0, le=10000)
    startTime: datetime
    endTime: datetime

    @validator('endTime')
    def validate_end_time(cls, v, values):
        if 'startTime' in values and v <= values['startTime']:
            raise ValueError('endTime must be after startTime')
        return v

    @validator('officerId')
    def validate_officer_id(cls, v):
        if not v or v.strip() == "":
            raise ValueError('officerId cannot be empty')
        return v.strip()

    @validator('location')
    def validate_location(cls, v):
        if not v or v.strip() == "":
            raise ValueError('location cannot be empty')
        return v.strip()

class CheckInSchema(BaseModel):
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    selfieUrl: str = Field(..., min_length=1)
    remarks: Optional[str] = None

    @validator('selfieUrl')
    def validate_selfie_url(cls, v):
        if not v or v.strip() == "":
            raise ValueError('selfieUrl cannot be empty')
        return v.strip()

    @validator('remarks')
    def validate_remarks(cls, v):
        if v and len(v.strip()) > 500:
            raise ValueError('remarks cannot exceed 500 characters')
        return v.strip() if v else None

class LocationUpdateSchema(BaseModel):
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)

class LocationUpdateRequest(BaseModel):
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    dutyId: str = Field(..., min_length=1)
    location_verified: bool

    @validator('dutyId')
    def validate_duty_id(cls, v):
        if not v or v.strip() == "":
            raise ValueError('dutyId cannot be empty')
        return v.strip()