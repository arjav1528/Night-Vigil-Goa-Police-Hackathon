from datetime import datetime
import requests 
from typing import Optional, List
from fastapi import APIRouter, Depends, Request, HTTPException, status
from fastapi.responses import JSONResponse
from prisma import Prisma
from models.model import User
from dotenv import load_dotenv
import os
from enum import Enum
from models.schemas import UserOut
from security import get_current_user

load_dotenv()

SECRET_KEY = os.getenv("SECRET_KEY")
if not SECRET_KEY:
    raise ValueError("SECRET_KEY environment variable is required")

db = Prisma()
FACE_RECOG_SERVICE_URL = os.getenv("FACE_RECOG_SERVICE_URL")

router = APIRouter(
    prefix="/users",
    tags=["auth"]
)

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

def validate_request_data(req_data: dict, required_fields: list) -> dict:
    """Validate request data and return cleaned data"""
    if not req_data or not isinstance(req_data, dict):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid request body"
        )
    
    missing_fields = [field for field in required_fields if not req_data.get(field)]
    if missing_fields:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Missing required fields: {', '.join(missing_fields)}"
        )
    
    # Clean string fields
    cleaned_data = {}
    for key, value in req_data.items():
        if isinstance(value, str):
            cleaned_data[key] = value.strip()
        else:
            cleaned_data[key] = value
    
    return cleaned_data

@router.post("/register")
async def register(request: Request):
    try:
        await ensure_db_connection()
        
        req = await request.json()
        req_data = validate_request_data(req, ["empid", "password", "role"])
        
        empid = req_data.get("empid")
        password = req_data.get("password")
        profileImages = req_data.get("profileImages", [])
        role = req_data.get("role", "OFFICER")
        
        # Validate empid format
        if len(empid) < 3:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="empid must be at least 3 characters long"
            )
        
        # Validate password strength
        if len(password) < 6:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="password must be at least 6 characters long"
            )
        
        # Validate role
        if role not in ["ADMIN", "OFFICER"]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="role must be either ADMIN or OFFICER"
            )
        
        # Validate profileImages
        if profileImages and not isinstance(profileImages, list):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="profileImages must be a list"
            )
        
        # Check for existing user
        existing_user = await db.user.find_unique(where={"empid": empid})
        if existing_user:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="User with this empid already exists"
            )
        
        # Create user with validation
        user = User(empid=empid, role=role, profileImage=profileImages or [])
        user.set_password(password)
        print("User object created:", user.empid, user.role,user.passwordHash)
        
        # Create user in database with transaction-like behavior
        try:
            result = await db.user.create(
                data={
                    "id": user.id,
                    "empid": user.empid,
                    "role": user.role.value if isinstance(user.role, Enum) else user.role,
                    "profileImage": user.profileImage,
                    "passwordHash": user.passwordHash,
                    "createdAt": user.createdAt,
                    "updatedAt": user.updatedAt,
                }
            )
            
            return JSONResponse(
                status_code=status.HTTP_201_CREATED,
                content={"detail": "User registered successfully", "user_id": result.id}
            )
            
        except Exception as db_error:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to create user in database: {str(db_error)}"
            )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Registration failed: {str(e)}"
        )

@router.post("/login")
async def login(request: Request):
    try:
        await ensure_db_connection()
        
        req = await request.json()
        req_data = validate_request_data(req, ["empid", "password"])
        
        empid = req_data.get("empid")
        password = req_data.get("password")
        
        # Find user
        user_record = await db.user.find_unique(where={"empid": empid})
        if not user_record:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )
        
        # Create user model with null safety
        user_model = User(
            id=user_record.id,
            empid=user_record.empid,
            role=user_record.role,
            profileImage=user_record.profileImage if user_record.profileImage else [],
            passwordHash=user_record.passwordHash,
            createdAt=user_record.createdAt,
            updatedAt=user_record.updatedAt
        )
        
        # Verify password
        if not user_model.verify_password(password):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid credentials"
            )
        
        # Generate token
        token = user_model.generate_token(SECRET_KEY)
        
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={
                "access_token": token,
                "token_type": "bearer",
                "user": {
                    "id": user_model.id,
                    "empid": user_model.empid,
                    "role": user_model.role.value if isinstance(user_model.role, Enum) else user_model.role
                }
            }
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Login failed: {str(e)}"
        )

@router.post("/admin/login")
async def admin_login(request: Request):
    try:
        await ensure_db_connection()
        
        req = await request.json()
        req_data = validate_request_data(req, ["empid", "password"])
        
        empid = req_data.get("empid")
        password = req_data.get("password")
        
        # Find admin user
        user_record = await db.user.find_unique(where={"empid": empid, "role": "ADMIN"})
        if not user_record:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Admin user not found"
            )
        
        # Create user model
        user_model = User(
            id=user_record.id,
            empid=user_record.empid,
            role=user_record.role,
            profileImage=user_record.profileImage if user_record.profileImage else [],
            passwordHash=user_record.passwordHash,
            createdAt=user_record.createdAt,
            updatedAt=user_record.updatedAt
        )
        print("Admin user found:", user_model.role)
        
        # Verify password
        if not user_model.verify_password(password):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid credentials"
            )
        
        token = user_model.generate_token(SECRET_KEY)
        
        return JSONResponse(
            status_code=status.HTTP_200_OK,
            content={
                "access_token": token,
                "token_type": "bearer",
                "user": {
                    "id": user_model.id,
                    "empid": user_model.empid,
                    "role": user_model.role.value if isinstance(user_model.role, Enum) else user_model.role
                }
            }
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Admin login failed: {str(e)}"
        )

@router.post('/admin/register')
async def admin_register(request: Request):
    try:
        await ensure_db_connection()
        
        req = await request.json()
        req_data = validate_request_data(req, ["empid", "password"])
        
        empid = req_data.get("empid")
        password = req_data.get("password")
        
        # Validate admin credentials
        if len(empid) < 3:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Admin empid must be at least 3 characters long"
            )
        
        if len(password) < 8:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Admin password must be at least 8 characters long"
            )
        
        # Check if admin already exists
        existing_admin = await db.user.find_unique(where={"empid": empid})
        if existing_admin:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Admin with this empid already exists"
            )
        
        # Create admin user
        new_admin = User(empid=empid, role="ADMIN")
        new_admin.set_password(password)
        
        await db.user.create(data={
            "id": new_admin.id,
            "empid": new_admin.empid,
            "role": new_admin.role,
            "passwordHash": new_admin.passwordHash,
            "createdAt": new_admin.createdAt,
            "updatedAt": new_admin.updatedAt,
        })
        
        return JSONResponse(
            status_code=status.HTTP_201_CREATED,
            content={"detail": "Admin registered successfully", "admin_id": new_admin.id}
        )
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Admin registration failed: {str(e)}"
        )

@router.get("/me", response_model=UserOut)
async def read_users_me(current_user: User = Depends(get_current_user)):
    if not current_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User authentication failed"
        )
    return current_user









