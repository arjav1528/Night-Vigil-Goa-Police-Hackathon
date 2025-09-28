from fastapi import APIRouter, HTTPException, Depends, Request, status
from typing import List, Optional
from datetime import datetime, timezone
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
from math import radians, sin, cos, sqrt, atan2

load_dotenv()

FACE_RECOG_SERVICE_URL = os.getenv("FACE_RECOG_SERVICE_URL")

router = APIRouter(prefix="/duties", tags=["Duties"])
db = Prisma()

async def ensure_db_connection():
    """Ensure database connection with error handling"""
    try:
        if not db.is_connected():
            await db.connect()
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database connection failed: {str(e)}"
        )

def calculate_distance(lat1, lon1, lat2, lon2):
    """Calculate distance between two coordinates with input validation"""
    try:
        # Validate coordinates
        if not all(isinstance(coord, (int, float)) for coord in [lat1, lon1, lat2, lon2]):
            raise ValueError("Coordinates must be numeric")
        
        if not (-90 <= lat1 <= 90) or not (-90 <= lat2 <= 90):
            raise ValueError("Latitude must be between -90 and 90")
        
        if not (-180 <= lon1 <= 180) or not (-180 <= lon2 <= 180):
            raise ValueError("Longitude must be between -180 and 180")
        
        R = 6371000  # Radius of Earth in meters
        lat1_rad, lon1_rad, lat2_rad, lon2_rad = map(radians, [lat1, lon1, lat2, lon2])
        dlon = lon2_rad - lon1_rad
        dlat = lat2_rad - lat1_rad
        a = sin(dlat / 2)**2 + cos(lat1_rad) * cos(lat2_rad) * sin(dlon / 2)**2
        c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    except Exception as e:
        raise ValueError(f"Distance calculation failed: {str(e)}")

@router.post("/", status_code=201)
async def create_duty(duty_data: DutyCreateSchema, admin: User = Depends(get_current_admin_user)):
    try:
        await ensure_db_connection()
        
        if not admin:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Admin authentication required"
            )
        
        # Validate officer exists
        officer = await db.user.find_unique(where={"id": duty_data.officerId, "role": "OFFICER"})
        if not officer:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Officer not found"
            )
        
        # Check for overlapping duties
        overlapping_duty = await db.dutyassignment.find_first(
            where={
                "officerId": duty_data.officerId,
                "OR": [
                    {
                        "AND": [
                            {"startTime": {"lte": duty_data.startTime}},
                            {"endTime": {"gt": duty_data.startTime}}
                        ]
                    },
                    {
                        "AND": [
                            {"startTime": {"lt": duty_data.endTime}},
                            {"endTime": {"gte": duty_data.endTime}}
                        ]
                    }
                ]
            }
        )
        
        if overlapping_duty:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Officer already has an overlapping duty assignment"
            )
        
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
        
        return JSONResponse(
            status_code=status.HTTP_201_CREATED,
            content={"detail": "Duty created successfully", "duty_id": created_record.id}
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create duty: {str(e)}"
        )

@router.get("/")
async def get_all_duties(admin: User = Depends(get_current_admin_user)):
    try:
        await ensure_db_connection()
        
        if not admin:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Admin authentication required"
            )
        
        duties = await db.dutyassignment.find_many()
        
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={"duties": duties, "count": len(duties)}
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch duties: {str(e)}"
        )

@router.get("/my-duties")
async def get_my_duties(current_user: User = Depends(get_current_user)):
    try:
        await ensure_db_connection()
        
        if not current_user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User authentication required"
            )
        
        duties = await db.dutyassignment.find_many(
            where={"officerId": current_user.id},
            order={"startTime": "desc"}
        )

        Duties = []
        for duty_data in duties:
            try:
                duty = DutyAssignment(
                    officerId=duty_data.officerId,
                    assignedBy=duty_data.assignedBy,
                    location=duty_data.location,
                    latitude=duty_data.latitude,
                    longitude=duty_data.longitude,
                    radius=duty_data.radius,
                    startTime=duty_data.startTime,
                    endTime=duty_data.endTime,
                    status=DutyStatus(duty_data.status) if isinstance(duty_data.status, str) else duty_data.status,
                    officer=current_user
                )
                Duties.append(duty)
            except Exception as duty_error:
                print(f"Error processing duty {duty_data.id}: {duty_error}")
                continue

        
        
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={"duties": [duty.to_dict() for duty in Duties], "count": len(Duties)}
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch user duties: {str(e)}"
        )

@router.post("/{duty_id}/checkin")
async def duty_check_in(
    duty_id: str,
    check_in_data: CheckInSchema,  
    current_user: User = Depends(get_current_user)
):
    try:
        await ensure_db_connection()
        
        if not current_user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User authentication required"
            )
        
        if not duty_id or duty_id.strip() == "":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="duty_id is required"
            )
        
        # Find duty
        duty = await db.dutyassignment.find_unique(where={"id": duty_id})
        if not duty:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Duty not found"
            )
        
        if duty.officerId != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Duty not assigned to you"
            )
        
        # Check if duty is in valid time range - fix timezone issue
        current_time = datetime.now(timezone.utc)
        
        # Ensure duty times are timezone-aware
        duty_start = duty.startTime
        duty_end = duty.endTime
        
        if duty_start.tzinfo is None:
            duty_start = duty_start.replace(tzinfo=timezone.utc)
        if duty_end.tzinfo is None:
            duty_end = duty_end.replace(tzinfo=timezone.utc)
        
        if current_time < duty_start:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Duty has not started yet"
            )
        
        if current_time > duty_end:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Duty has already ended"
            )
        
        # Check if already checked in
        existing_log = await db.dutylog.find_first(
            where={"dutyId": duty_id, "officerId": current_user.id}
        )
        
        if existing_log:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Already checked in for this duty"
            )
        
        # Calculate distance with error handling
        try:
            distance = calculate_distance(
                check_in_data.latitude, 
                check_in_data.longitude, 
                duty.latitude, 
                duty.longitude
            )
            location_verified = distance <= duty.radius
        except ValueError as e:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid coordinates: {str(e)}"
            )
        
        if not location_verified:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"You are {distance:.2f}m away from duty location. Required: within {duty.radius}m"
            )
        
        face_verified = True  # Default to true for now
        
        # Create duty log
        duty_log_data = {
            "id": __import__('uuid').uuid4().hex,
            "dutyId": duty_id,
            "officerId": current_user.id,
            "checkinTime": current_time,
            "selfiePath": check_in_data.selfieUrl,
            "locationVerified": location_verified,
            "faceVerified": face_verified,
            "remarks": check_in_data.remarks or "Check-in completed",
            "createdAt": current_time,
            "updatedAt": current_time
        }
        
        await db.dutylog.create(data=duty_log_data)
        
        # Update duty status
        if location_verified and face_verified:
            await db.dutyassignment.update(
                where={"id": duty_id},
                data={"status": DutyStatus.COMPLETED.value}
            )
        
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={
                "status": "success", 
                "location_verified": location_verified, 
                "face_verified": face_verified,
                "distance": round(distance, 2),
                "duty_status": DutyStatus.COMPLETED.value if (location_verified and face_verified) else DutyStatus.PENDING.value
            }
        )
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error during check-in: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Check-in failed: {str(e)}"
        )

@router.post("/{duty_id}/location-update")
async def duty_location_update(
    duty_id: str,
    location_data: LocationUpdateSchema,
    current_user: User = Depends(get_current_user)
):
    try:
        await ensure_db_connection()
        
        if not current_user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User authentication required"
            )
        
        if not duty_id or duty_id.strip() == "":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="duty_id is required"
            )
        
        duty = await db.dutyassignment.find_unique(where={"id": duty_id})
        if not duty:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Duty not found"
            )
        
        if duty.officerId != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Duty not assigned to you"
            )
        
        try:
            distance = calculate_distance(
                location_data.latitude, 
                location_data.longitude, 
                duty.latitude, 
                duty.longitude
            )
            is_in_radius = distance <= duty.radius
        except ValueError as e:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid coordinates: {str(e)}"
            )
        
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={
                "status": "location received", 
                "in_radius": is_in_radius,
                "distance": round(distance, 2),
                "required_radius": duty.radius
            }
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Location update failed: {str(e)}"
        )

@router.get("/users/all", response_model=List[UserOut])
async def get_all_users(admin: User = Depends(get_current_admin_user)):
    try:
        await ensure_db_connection()
        
        if not admin:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Admin authentication required"
            )
        
        users = await db.user.find_many(
            where={"role": "OFFICER"},
            order={"createdAt": "desc"}
            )
        
        user_list = []
        for user_data in users:
            try:
                user = User(
                    id=user_data.id,
                    empid=user_data.empid,
                    role=user_data.role,
                    profileImage=user_data.profileImage if user_data.profileImage else [],
                    createdAt=user_data.createdAt
                )
                user_list.append(user)
            except Exception as user_error:
                print(f"Error processing user {user_data.id}: {user_error}")
                continue
        
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={
                "users": [user.to_dict() for user in user_list],
                "count": len(user_list)
            }
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch users: {str(e)}"
        )

@router.post("/location-update")
async def location_update(
    request: LocationUpdateRequest,
    current_user: User = Depends(get_current_user)
):
    try:
        await ensure_db_connection()
        
        if not current_user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User authentication required"
            )
        
        # Validate duty exists
        duty = await db.dutyassignment.find_unique(where={"id": request.dutyId})
        if not duty:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Duty not found"
            )
        
        if duty.officerId != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Duty not assigned to you"
            )
        
        current_time = datetime.now(timezone.utc)
        
        # Find the most recent log for the duty
        latest_log = await db.dutylog.find_first(
            where={"dutyId": request.dutyId, "officerId": current_user.id},
            order={"checkinTime": "desc"}
        )
        
        if not latest_log:
            # Create initial log if no check-in exists
            log_data = {
                "id": __import__('uuid').uuid4().hex,
                "dutyId": request.dutyId,
                "officerId": current_user.id,
                "locationVerified": request.location_verified,
                "remarks": f"Officer location tracking: {'Inside' if request.location_verified else 'Outside'} duty radius at ({request.latitude}, {request.longitude})",
                "checkinTime": current_time,
                "createdAt": current_time,
                "updatedAt": current_time
            }
            
            await db.dutylog.create(data=log_data)
            
            return JSONResponse(
                status_code=status.HTTP_201_CREATED,
                content={"status": "initial_location_log_created"}
            )
        
        # Update existing log
        update_data = {
            "locationVerified": request.location_verified,
            "remarks": f"Location update: {'Inside' if request.location_verified else 'Outside'} duty radius at ({request.latitude}, {request.longitude}). Last updated: {current_time.isoformat()}",
            "updatedAt": current_time
        }
        
        await db.dutylog.update(
            where={"id": latest_log.id},
            data=update_data
        )
        
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={"status": "location_log_updated_successfully"}
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Location update failed: {str(e)}"
        )

@router.get("/location-update/{officer_id}")
async def get_location_updates(
    officer_id: str, 
    admin: User = Depends(get_current_admin_user)
):
    try:
        await ensure_db_connection()
        
        if not admin:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Admin authentication required"
            )
        
        if not officer_id or officer_id.strip() == "":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="officer_id is required"
            )
        
        # Verify officer exists
        officer = await db.user.find_unique(where={"id": officer_id, "role": "OFFICER"})
        if not officer:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Officer not found"
            )
        
        # Get latest location update
        location_update = await db.dutylog.find_first(
            where={"officerId": officer_id},
            order={"updatedAt": "desc"},
            include={"duty": {"select": {"location": True, "latitude": True, "longitude": True}}}
        )
        
        if not location_update:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No location updates found for this officer"
            )
        
        # Create response with null safety
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
        
        response_data = location_log.to_dict()
        if hasattr(location_update, 'duty') and location_update.duty:
            response_data["duty_info"] = {
                "location": location_update.duty.location,
                "latitude": location_update.duty.latitude,
                "longitude": location_update.duty.longitude
            }
        
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content=response_data
        )
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch location updates: {str(e)}"
        )
