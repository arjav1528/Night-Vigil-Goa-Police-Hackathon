from fastapi import APIRouter, HTTPException, Depends, Request
from typing import List, Optional
from datetime import datetime
from fastapi.responses import JSONResponse
from prisma import Prisma
import os
from models.model import User, DutyAssignment, DutyLog, DutyStatus
from models.schemas import CheckInSchema, DutyCreateSchema, LocationUpdateRequest, LocationUpdateSchema, UserOut
from security import get_current_admin_user, get_current_user
from dotenv import load_dotenv
from enum import Enum
import requests
from fastapi.concurrency import run_in_threadpool
load_dotenv()



FACE_RECOG_SERVICE_URL = os.getenv("FACE_RECOG_SERVICE_URL")

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
    try:
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
        if not db.is_connected():
            await db.connect()
        created_record = await db.dutyassignment.create(data=new_duty.to_dict())
        return created_record
    except Exception as e:
        return JSONResponse(status_code=500, content={"detail": str(e)})

@router.get("/")
async def get_all_duties(admin: User = Depends(get_current_admin_user)):
    try:
        if not db.is_connected():
            await db.connect()

        duties = await db.dutyassignment.find_many()
        print(duties)
        return duties
    except Exception as e:
        return JSONResponse(status_code=500, content={"detail": str(e)})

@router.get("/my-duties")
async def get_my_duties(current_user: User = Depends(get_current_user)):
    if not db.is_connected():
        await db.connect()
    print(f"Fetching duties for user: {current_user.empid}")
    return await db.dutyassignment.find_many(where={"officerId": current_user.id})

@router.post("/{duty_id}/checkin")
async def duty_check_in(
    duty_id: str,
    check_in_data: CheckInSchema,  
    current_user: User = Depends(get_current_user)
):
    try:
        if not db.is_connected():
            await db.connect()

        print(f"User {current_user.empid} attempting to check in for duty {duty_id} with data")

        duty = await db.dutyassignment.find_unique(where={"id": duty_id})
        if not duty or duty.officerId != current_user.id:
            raise HTTPException(status_code=403, detail="Duty not found or not assigned to you.")

        distance = calculate_distance(check_in_data.latitude, check_in_data.longitude, duty.latitude, duty.longitude)
        location_verified = distance <= duty.radius

        if not location_verified:
            return JSONResponse(status_code=400, content={"detail": "You are outside the duty location radius."})

        face_verified = False

        if FACE_RECOG_SERVICE_URL and check_in_data.selfieUrl:
            try:
                verify_payload = {
                    "user_id": current_user.id,
                    "selfie_url": check_in_data.selfieUrl
                }
                face_response = await run_in_threadpool(
                    requests.post, 
                    url=f"{FACE_RECOG_SERVICE_URL}/verify", 
                    json=verify_payload
                )
                if face_response.status_code == 200:
                    face_result = face_response.json()
                    face_verified = face_result.get("verified", False)

                    if not face_verified:
                        return JSONResponse(status_code=400, content={"detail": "Face verification failed."})
                else:
                    return JSONResponse(status_code=face_response.status_code, content={"detail": "Face recognition failed"})
            except Exception as e:
                return JSONResponse(status_code=500, content={"detail": f"Error calling face recognition service: {str(e)}"})



        duty_log_data = {
            "id": DutyLog.generate_id() if hasattr(DutyLog, 'generate_id') else __import__('uuid').uuid4().hex,
            "dutyId": duty_id,
            "officerId": current_user.id,
            "checkinTime": datetime.now(), 
            "selfiePath": check_in_data.selfieUrl,
            "locationVerified": location_verified,
            "faceVerified": face_verified,
            "remarks": check_in_data.remarks,
        }
        
        await db.dutylog.create(data=duty_log_data)

        if location_verified and face_verified:
            await db.dutyassignment.update(
                where={"id": duty_id},
                data={"status": DutyStatus.COMPLETED.value}
            )

        return {"status": "success", "location_verified": location_verified, "face_verified": face_verified}
    except Exception as e:
        return JSONResponse(status_code=500, content={"detail": str(e)})



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
    try:
        if not db.is_connected():
            await db.connect()
        users = await db.user.find_many(
            where={"role": "OFFICER"}
        )
        user_list = [User(**u.dict()) for u in users]
        for user in user_list:
            print(f"User fetched: {user.to_dict()}")
        return JSONResponse(status_code=200, content=[user.to_dict() for user in user_list])
    except Exception as e:
        print(f"Error fetching users: {e}")
        return JSONResponse(status_code=500, content={"detail": "Internal server error"})




@router.post("/location-update")
async def location_update(
    request: LocationUpdateRequest,
    current_user: User = Depends(get_current_user)
):
    
    print(f"--- ALERT: Officer {current_user.empid} is outside their duty radius! ---")
    
    try:
        # 1. Find the most recent log for the given duty
        latest_log = await db.dutylog.find_first(
            where={"dutyId": request.dutyId},
            order={"checkinTime": "desc"} # 'desc' gets the most recent one
        )

        if not latest_log:
            # This case happens if the officer is out of radius before their first check-in
            # We can create an initial log here.
            await db.dutylog.create(data={
                'dutyId': request.dutyId,
                'officerId': current_user.id,
                'locationVerified': request.location_verified,
                'remarks': f"Officer started duty outside of designated radius at ({request.latitude}, {request.longitude}).",
                'updatedAt': datetime.now().isoformat(),
                'createdAt': datetime.now().isoformat()
            })
            return {"status": "initial_out_of_radius_log_created"}

        # 2. Update the found log with the new status
        await db.dutylog.update(
            where={"id": latest_log.id},
            data={
                'locationVerified': request.location_verified,
                'remarks': f"Officer detected outside duty radius at ({request.latitude}, {request.longitude}). Last checked at {datetime.now().isoformat()}"
            }
        )

        return {"status": "latest_log_updated_successfully"}
    
    except Exception as e:
        print(f"Failed to update duty log for out-of-radius event: {e}")
        raise HTTPException(status_code=500, detail="Could not update the location log.")
    


    

@router.get("/location-update/{id}")
async def get_location_updates(request: Request, id: str, admin: User = Depends(get_current_admin_user)):
    try:

        if not db.is_connected():
            await db.connect()
        location_update = await db.dutylog.find_first(
            where={"officerId": id},
            order={"checkinTime": "desc"},
        )

        print(str(location_update))
        location_log = DutyLog(
            id=location_update.id,
            dutyId=location_update.dutyId,
            officerId=location_update.officerId,
            checkinTime=location_update.checkinTime,
            selfiePath=location_update.selfiePath,
            faceVerified=location_update.faceVerified,
            locationVerified=location_update.locationVerified,
            remarks=location_update.remarks,
            createdAt=location_update.createdAt,
            updatedAt=location_update.updatedAt
        )

        # Fix: Create DutyLog objects properly by mapping database fields to constructor parameters
        

        if not location_log:
            return JSONResponse(status_code=404, content={"detail": "No location updates found for this officer."})

        return JSONResponse(status_code=200, content=location_log.to_dict())
    except Exception as e:
        print(f"Error fetching location updates: {e}")
        return JSONResponse(status_code=500, content={"detail": "Internal server error"})
