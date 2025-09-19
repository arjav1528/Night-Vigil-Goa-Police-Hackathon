from fastapi import APIRouter, HTTPException, Depends
from typing import List, Optional
from datetime import datetime
from prisma import Prisma
import os
from models.model import User, DutyAssignment, DutyLog, DutyStatus
from models.schemas import CheckInSchema, DutyCreateSchema, LocationUpdateSchema, UserOut
from security import get_current_admin_user, get_current_user





router = APIRouter(prefix="/duties", tags=["Duties"])
db = Prisma()

from math import radians, sin, cos, sqrt, atan2

def calculate_distance(lat1, lon1, lat2, lon2):
    R = 6371000  # Radius of Earth in meters
    lat1_rad, lon1_rad, lat2_rad, lon2_rad = map(radians, [lat1, lon1, lat2, lon2])
    dlon = lon2_rad - lon1_rad
    dlat = lat2_rad - lat1_rad
    a = sin(dlat / 2)**2 + cos(lat1_rad) * cos(lat2_rad) * sin(dlon / 2)**2
    c = 2 * atan2(sqrt(a), sqrt(1 - a))
    return R * c

@router.post("/", status_code=201)
async def create_duty(duty_data: DutyCreateSchema, admin: User = Depends(get_current_admin_user)):
    new_duty = DutyAssignment(
        officerId=duty_data.officerId,
        assignedBy=admin.id,
        location=duty_data.location,
        latitude=duty_data.latitude,
        longitude=duty_data.longitude,
        radius=duty_data.radius,
        startTime=duty_data.startTime,
        endTime=duty_data.endTime
    )
    created_record = await db.dutyassignment.create(data=new_duty.to_dict())
    return created_record

@router.get("/")
async def get_all_duties(admin: User = Depends(get_current_admin_user)):
    return await db.dutyassignment.find_many(include={"officer": True})

@router.get("/my-duties")
async def get_my_duties(current_user: User = Depends(get_current_user)):
    return await db.dutyassignment.find_many(where={"officerId": current_user.id})

@router.post("/{duty_id}/checkin")
async def duty_check_in(
    duty_id: str,
    check_in_data: CheckInSchema,  
    current_user: User = Depends(get_current_user)
):
    duty = await db.dutyassignment.find_unique(where={"id": duty_id})
    if not duty or duty.officerId != current_user.id:
        raise HTTPException(status_code=403, detail="Duty not found or not assigned to you.")

    distance = calculate_distance(check_in_data.latitude, check_in_data.longitude, duty.latitude, duty.longitude)
    location_verified = distance <= duty.radius

    face_verified = True

    duty_log = DutyLog(
        dutyId=duty_id,
        officerId=current_user.id,
        selfiePath=check_in_data.selfieUrl,
        locationVerified=location_verified,
        faceVerified=face_verified,
        remarks=check_in_data.remarks
    )
    
    await db.dutylog.create(data=duty_log.to_dict())

    if location_verified and face_verified:
        await db.dutyassignment.update(
            where={"id": duty_id},
            data={"status": DutyStatus.COMPLETED.value}
        )

    return {"status": "Check-in successful", "location_verified": location_verified, "face_verified": face_verified}



@router.post("/{duty_id}/location-update")
async def duty_location_update(
    duty_id: str,
    location_data: LocationUpdateSchema,
    current_user: User = Depends(get_current_user)
):
    duty = await db.dutyassignment.find_unique(where={"id": duty_id})
    if not duty or duty.officerId != current_user.id:
        raise HTTPException(status_code=403, detail="Duty not found or not assigned to you.")

    distance = calculate_distance(location_data.latitude, location_data.longitude, duty.latitude, duty.longitude)
    is_in_radius = distance <= duty.radius

    print(f"Officer {current_user.empid} is {'inside' if is_in_radius else 'OUTSIDE'} the radius for duty {duty_id}.")
    
    if not is_in_radius:
        pass

    return {"status": "location received", "in_radius": is_in_radius}



@router.get("/users/all", response_model=List[UserOut])
async def get_all_users(admin: User = Depends(get_current_admin_user)):
    users = await db.user.find_many(
        where={"role": "OFFICER"}
    )
    return users


